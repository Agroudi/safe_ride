import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_monitor.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

void main() {
  late FirestoreJourneyRepository journeys;
  late FakeLocation location;
  late MemoryTrackStore store;
  late FakeRoute route;
  late FakeRouting routing;
  late MemoryIncidentRepository incidents;
  late JourneyTracker tracker;
  late DateTime now;
  final List<JourneyMapCubit> cubits = <JourneyMapCubit>[];

  setUp(() {
    final _Session session = _Session();
    journeys = FirestoreJourneyRepository(FakeFirebaseFirestore(), session);
    location = FakeLocation(now: LocationAccess.granted);
    store = MemoryTrackStore();
    route = FakeRoute();
    routing = FakeRouting();
    incidents = MemoryIncidentRepository();
    now = DateTime.now().toUtc();
    tracker = JourneyTracker(
      location: location,
      store: store,
      route: route,
      journeys: journeys,
      session: session,
      observer: IncidentMonitor(incidents),
      translate: (String k) => k,
      clock: () => now,
      tickEvery: const Duration(days: 1),
    );
  });

  tearDown(() async {
    for (final JourneyMapCubit c in cubits) {
      await c.close();
    }
    cubits.clear();
    await tracker.dispose();
  });

  JourneyMapCubit map() {
    final JourneyMapCubit c = JourneyMapCubit(
      tracker,
      journeys,
      routing,
      // Long enough that a busy machine cannot end it before it is read.
      resumedFor: const Duration(milliseconds: 500),
    );
    cubits.add(c);
    return c;
  }

  Future<JourneyModel> started({bool places = false}) async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
      originPlace: places
          ? const JourneyPlace(name: 'Home', lat: 24.7, lng: 46.67)
          : null,
      destinationPlace: places
          ? const JourneyPlace(name: 'Work', lat: 24.8, lng: 46.67)
          : null,
    );
    await journeys.start(
      j.id,
      checklistVersion: 1,
      confirmed: JourneyChecklist.itemsOf(1).toSet(),
    );
    return j;
  }

  Future<void> flush() => pumpEventQueue(times: 100);

  /// A trusted fix [metres] north of the start.
  Future<void> fix(double metres, {double? speed, double accuracy = 8}) async {
    now = now.add(const Duration(seconds: 2));
    location.fix(
      24.7 + metres / 111195,
      46.67,
      at: now,
      accuracy: accuracy,
      speed: speed,
    );
    await flush();
  }

  group('reuses the tracker', () {
    test('the map opens no location subscription of its own', () async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      expect(location.listens, 1);
      await map().open(j.id);
      await map().open(j.id);
      await flush();
      expect(location.listens, 1);
    });

    test('opened first, it joins the one recording', () async {
      final JourneyModel j = await started();
      await map().open(j.id);
      expect(tracker.journeyId, j.id);
      expect(location.listens, 1);
      expect(location.asked, 0, reason: 'it never prompts');
    });

    test('closing the map stops nothing', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      await c.close();
      cubits.remove(c);
      await fix(30);
      expect(tracker.journeyId, j.id);
      expect(await store.points('sara', j.id), hasLength(2));
    });

    test('it writes nothing: no more route writes than without it', () async {
      final JourneyModel j = await started();
      await map().open(j.id);
      final int saves = store.saves;
      await fix(0);
      await fix(30);
      expect(route.uploads, isEmpty);
      expect(store.saves - saves, 2, reason: 'the tracker\'s own, one a point');
    });

    test('incident detection still gets every fix', () async {
      final JourneyModel j = await started();
      await map().open(j.id);
      final List<String> seen = <String>[];
      final StreamSubscription<void> s = incidents.changes.listen(
        (_) => seen.add('change'),
      );
      await fix(0, speed: 15);
      await fix(30, speed: 15);
      await s.cancel();
      expect(tracker.current?.distanceMeters, greaterThan(0));
    });
  });

  group('the route', () {
    test('picks up what was recorded before it opened', () async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      await fix(0);
      await fix(30);
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.segments.single, hasLength(2));
      expect(c.state.current?.lat, closeTo(24.7 + 30 / 111195, 1e-6));
    });

    test('grows as trusted points arrive; the marker moves', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      final int version = c.state.routeVersion;
      final TrackPoint? first = c.state.current;
      await fix(30);
      expect(c.segments.single, hasLength(2));
      expect(c.state.routeVersion, version + 1);
      expect(c.state.current, isNot(first));
    });

    test('rejected fixes never reach the map', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      await fix(5000, accuracy: 200);
      expect(c.segments.single, hasLength(1));
      expect(c.state.current?.lat, closeTo(24.7, 1e-6));
    });

    test('standing still does not redraw the route', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      final int version = c.state.routeVersion;
      await fix(0);
      await fix(1);
      expect(c.state.routeVersion, version);
    });

    test('a gap stays a gap: one line per segment', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      await fix(30);
      now = now.add(const Duration(minutes: 5));
      await fix(400);
      await fix(430);
      expect(c.segments, hasLength(2));
      expect(c.segments[0], hasLength(2));
      expect(c.segments[1], hasLength(2));
    });

    test('segments survive reopening', () async {
      final JourneyModel j = await started();
      await store.saveSession(
        TrackSession(
          journeyId: j.id,
          uid: 'sara',
          recording: false,
          startedAt: now,
        ),
      );
      for (int i = 0; i < 4; i++) {
        await store.append(
          'sara',
          j.id,
          TrackPoint(
            lat: 24.7 + i / 1000,
            lng: 46.67,
            at: now.subtract(Duration(minutes: 10 - i)),
            accuracy: 8,
            segment: i ~/ 2,
          ),
        );
      }
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.segments, hasLength(2));
    });

    test('an ended journey shows the account\'s copy', () async {
      final JourneyModel j = await started();
      await journeys.complete(j.id);
      route.stored = <TrackPoint>[
        TrackPoint(lat: 24.7, lng: 46.67, at: now, accuracy: 8),
        TrackPoint(
          lat: 24.71,
          lng: 46.67,
          at: now.add(const Duration(minutes: 1)),
          accuracy: 8,
        ),
      ];
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.segments.single, hasLength(2));
      expect(c.state.status, MapTrackingStatus.completed);
      expect(location.listens, 0, reason: 'nothing starts for a closed one');
    });
  });

  group('how far it went', () {
    test('a finished journey shows what was recorded', () async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      await fix(0);
      await fix(100);
      await fix(200);
      await journeys.complete(j.id);
      await tracker.stop(j.id);
      await flush();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.state.status, MapTrackingStatus.completed);
      expect(c.state.distanceMeters, closeTo(200, 5));
    });

    test('opened mid-journey, it has the distance at once', () async {
      final JourneyModel j = await started();
      await tracker.start(j.id);
      await fix(0);
      await fix(100);
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.state.distanceMeters, closeTo(100, 5));
    });

    test('with no record of it, the distance is unknown, not zero', () async {
      final JourneyModel j = await started();
      await journeys.complete(j.id);
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.state.distanceMeters, isNull);
    });
  });

  group('the status', () {
    test('weak, lost, back again: the route stays through all of it', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      await fix(30);
      expect(c.state.status, MapTrackingStatus.recording);

      await fix(30, accuracy: 40);
      expect(c.state.status, MapTrackingStatus.weakSignal);

      now = now.add(JourneyTracker.signalLost + const Duration(seconds: 5));
      tracker.tick();
      await flush();
      expect(c.state.status, MapTrackingStatus.unavailable);
      expect(c.segments.single, hasLength(2));
      expect(c.state.current, isNotNull);

      await fix(60);
      expect(c.state.status, MapTrackingStatus.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(c.state.status, MapTrackingStatus.recording);
    });

    test('location switched off reads as interrupted', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      location.services.add(false);
      await flush();
      expect(c.state.status, MapTrackingStatus.interrupted);
      expect(c.segments, isNotEmpty);
    });

    test('no permission reads as interrupted, and asks nothing', () async {
      location.now = LocationAccess.denied;
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(c.state.status, MapTrackingStatus.interrupted);
      expect(location.asked, 0);
    });

    test('completing keeps the route and stops recording', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      await fix(30);
      await journeys.complete(j.id);
      await flush();
      await tracker.stop(j.id);
      await flush();
      expect(c.state.status, MapTrackingStatus.completed);
      expect(c.segments.single, hasLength(2));
      expect(tracker.journeyId, isNull);
    });

    test('a journey that does not exist says so', () async {
      final JourneyMapCubit c = map();
      await c.open('nope');
      expect(c.state.missing, isTrue);
    });
  });

  group('direction and progress', () {
    test('a direction only while really moving', () async {
      final JourneyModel j = await started();
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0, speed: 15);
      expect(c.state.heading, isNull, reason: 'one point has no direction');
      await fix(30, speed: 15);
      expect(c.state.heading, isNotNull);
      expect(c.state.heading!.abs(), lessThan(2), reason: 'due north');
      // Speed is smoothed: it takes a few slow readings to come down.
      for (double m = 60; m < 300; m += 30) {
        await fix(m, speed: 0);
      }
      expect(c.state.heading, isNull);
    });

    test('remaining only on the planned route', () async {
      routing.answer = const PlannedRoute(
        points: <LatLng>[LatLng(24.7, 46.67), LatLng(24.8, 46.67)],
        distanceMeters: 11000,
        durationSeconds: 600,
      );
      final JourneyModel j = await started(places: true);
      final JourneyMapCubit c = map();
      await c.open(j.id);
      expect(routing.asked, 1);
      await fix(1000);
      expect(c.state.progress?.remainingMeters, closeTo(10100, 200));
      expect(c.state.progress?.remainingSeconds, greaterThan(0));

      // Off to the side of the route: the figure goes, not a guess.
      now = now.add(const Duration(minutes: 1));
      location.fix(24.71, 46.7, at: now, accuracy: 8);
      await flush();
      expect(c.state.progress, isNull);
      expect(routing.asked, 1, reason: 'never re-routed per fix');
    });

    test('no routing, no remaining: and nothing else breaks', () async {
      final JourneyModel j = await started(places: true);
      final JourneyMapCubit c = map();
      await c.open(j.id);
      await fix(0);
      expect(c.state.planned, isNull);
      expect(c.state.progress, isNull);
      expect(c.state.current, isNotNull);
    });

    test('a journey from before maps never asks for a route', () async {
      final JourneyModel j = await started();
      await map().open(j.id);
      expect(routing.asked, 0);
    });
  });
}
