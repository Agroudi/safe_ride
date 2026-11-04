import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/route_math.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/location_source.dart';
import 'package:safe_ride/features/journeys/data/repository/route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/tracking_observer.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  String? uid = 'sara';
  final StreamController<void> changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => changed.stream;

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

/// Writes down what the tracker tells its observer.
class _Spy implements TrackingObserver {
  final List<String> calls = <String>[];
  DateTime? lastFixBefore;

  @override
  void started(
    String uid,
    String journeyId,
    DateTime at, {
    DateTime? lastFixBefore,
  }) {
    this.lastFixBefore = lastFixBefore;
    calls.add('started $journeyId');
  }

  @override
  void fixed(String journeyId, LocationFix fix, DateTime at) =>
      calls.add('fixed');

  @override
  void ticked(String journeyId, DateTime at) => calls.add('ticked');

  @override
  void interrupted(String journeyId, InterruptionCause cause, DateTime at) =>
      calls.add('interrupted ${cause.name}');

  @override
  void paused(String journeyId) => calls.add('paused');

  @override
  void ended(String uid, String journeyId, DateTime at) => calls.add('ended');
}

void main() {
  late FakeFirebaseFirestore db;
  late _Session session;
  late FirestoreJourneyRepository journeys;
  late FakeLocation location;
  late MemoryTrackStore store;
  late DateTime now;
  final List<JourneyTracker> trackers = <JourneyTracker>[];

  setUp(() {
    db = FakeFirebaseFirestore();
    session = _Session();
    journeys = FirestoreJourneyRepository(db, session);
    location = FakeLocation(now: LocationAccess.granted);
    store = MemoryTrackStore();
    now = DateTime.now().toUtc();
  });

  tearDown(() async {
    for (final JourneyTracker t in trackers) {
      await t.dispose();
    }
    trackers.clear();
  });

  JourneyTracker tracker({RouteRepository? route, TrackingObserver? observer}) {
    final JourneyTracker t = JourneyTracker(
      location: location,
      store: store,
      route: route ?? FirestoreRouteRepository(db, session),
      journeys: journeys,
      session: session,
      observer: observer,
      translate: (String key) => key,
      clock: () => now,
      // Ticks are driven by hand.
      tickEvery: const Duration(days: 1),
    );
    trackers.add(t);
    return t;
  }

  Future<JourneyModel> planned([String to = 'Work']) => journeys.plan(
    origin: 'Home',
    destination: to,
    departsAt: DateTime.now().add(const Duration(hours: 1)),
  );

  Future<JourneyModel> started([String to = 'Work']) async {
    final JourneyModel j = await planned(to);
    await journeys.start(
      j.id,
      checklistVersion: JourneyChecklist.current,
      confirmed: JourneyChecklist.itemsOf(JourneyChecklist.current).toSet(),
    );
    return j;
  }

  /// Lets the fix stream and the tracker's queue run.
  Future<void> flush() => pumpEventQueue(times: 100);

  /// A fix [seconds] after the test's start, [metres] north of Riyadh's
  /// reference point.
  void fixAt(int seconds, double metres, {double accuracy = 8, double? speed}) {
    now = now.add(const Duration(seconds: 1));
    location.fix(
      24.7 + metres / 111195,
      46.67,
      at: now,
      accuracy: accuracy,
      speed: speed,
    );
  }

  test(
    'only a journey in progress is recorded, and nothing is asked',
    () async {
      location.now = LocationAccess.denied;
      final JourneyTracker t = tracker();
      final JourneyModel plan = await planned();
      expect(await t.start(plan.id), TrackStart.notActive);

      final JourneyModel j = await started('Gym');
      expect(await t.start(j.id), TrackStart.noAccess);
      expect(location.asked, 0);
      expect(location.listens, 0);
      expect(t.current, isNull);
    },
  );

  test('after the checklist it records once, however often asked', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    final List<TrackStart> results = await Future.wait(<Future<TrackStart>>[
      t.start(j.id),
      t.start(j.id),
    ]);
    expect(results, everyElement(TrackStart.recording));
    expect(await t.start(j.id), TrackStart.recording);
    expect(location.listens, 1);
    expect(t.current?.status, TrackingStatus.starting);
    expect(t.journeyId, j.id);
  });

  test('a start while the prompts are open waits for them', () async {
    location.now = LocationAccess.denied;
    final Completer<void> answered = Completer<void>();
    location.prompt = answered;
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    final Future<LocationAccess> asking = t.requestAccess();
    // The app resumes behind the dialog and tries to start.
    final Future<TrackStart> resumed = t.start(j.id);
    await flush();
    expect(location.listens, 0);

    location.now = LocationAccess.granted;
    answered.complete();
    expect(await asking, LocationAccess.granted);
    expect(await resumed, TrackStart.recording);
    expect(location.noticesAsked, 1);
    expect(location.listens, 1);
  });

  test('one journey at a time', () async {
    final JourneyTracker t = tracker();
    final JourneyModel a = await started('A');
    final JourneyModel b = await started('B');
    await t.start(a.id);
    expect(await t.start(b.id), TrackStart.otherJourney);
  });

  test('trusted fixes become route points; bad ones are left out', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);

    fixAt(1, 0);
    fixAt(2, 0, accuracy: 120); // inaccurate
    location.fix(0, 0, at: now); // invalid
    fixAt(3, 2); // under 5 m: no movement
    fixAt(4, 100);
    fixAt(5, 50000); // 50 km in a second: a jump
    await flush();

    final List<TrackPoint> points = await store.points('sara', j.id);
    expect(points, hasLength(2));
    expect(
      t.current!.distanceMeters,
      closeTo(RouteMath.between(points[0], points[1]), 1e-6),
    );
    expect(t.current!.distanceMeters, closeTo(100, 1));
    expect(t.current!.last, points[1]);
  });

  test('speed: current, then last known, never stale as current', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    expect(t.current!.speed, const SpeedReading.unavailable());

    fixAt(1, 0, speed: 10);
    await flush();
    expect(t.current!.speed.current, isTrue);
    expect(t.current!.speed.kmh, closeTo(36, 1e-9));

    now = now.add(const Duration(seconds: 15));
    t.tick();
    expect(t.current!.speed.current, isFalse);
    expect(t.current!.speed.kmh, closeTo(36, 1e-9));
  });

  test('GPS: a weak signal, then none', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    fixAt(1, 0, accuracy: 30);
    await flush();
    expect(t.current!.status, TrackingStatus.weakSignal);
    fixAt(2, 40);
    await flush();
    expect(t.current!.status, TrackingStatus.active);

    now = now.add(const Duration(seconds: 25));
    t.tick();
    expect(t.current!.status, TrackingStatus.noSignal);
  });

  test('permission taken away, then given back: the same recording', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    fixAt(1, 0);
    await flush();

    location.fixesController.addError(
      const LocationSourceError(LocationAccess.denied),
    );
    await flush();
    expect(t.current!.status, TrackingStatus.permissionRequired);

    location.now = LocationAccess.denied;
    expect(await t.start(j.id), TrackStart.noAccess);
    location.now = LocationAccess.granted;
    expect(await t.start(j.id), TrackStart.recording);
    expect(location.listens, 2);
    fixAt(2, 30);
    await flush();
    expect((await store.points('sara', j.id)), hasLength(2));
  });

  test('location services switched off', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    location.fixesController.addError(
      const LocationSourceError(LocationAccess.serviceOff),
    );
    await flush();
    expect(t.current!.status, TrackingStatus.locationOff);
  });

  test('chunks of 100 reach the account; a retry never duplicates', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    for (int i = 0; i < 150; i++) {
      fixAt(i, i * 20.0);
      // Each fix is handled as it comes, as on a phone: the test clock must
      // not run ahead of the queue, or older fixes read as stale.
      await pumpEventQueue(times: 20);
    }
    await flush();
    await t.sync();
    await t.sync();

    final String route = 'users/sara/journeys/${j.id}/route';
    final List<String> chunks = (await db.collection(route).get()).docs
        .map((d) => d.id)
        .toList();
    expect(chunks, <String>['00000', '00001']);
    expect(
      (await db.doc('$route/00000').get()).data()!['points'],
      hasLength(100),
    );
    expect(
      (await db.doc('$route/00001').get()).data()!['points'],
      hasLength(50),
    );
    final Map<String, dynamic> summary =
        (await db.doc('users/sara/journeys/${j.id}/tracking/summary').get())
            .data()!;
    expect(summary['pointCount'], 150);
    expect(summary['recording'], isTrue);
    expect(summary['distanceMeters'], closeTo(149 * 20, 2));
    expect((await store.session('sara', j.id))!.syncedCount, 150);
    expect(t.current!.sync, RouteSync.synced);
  });

  test(
    'offline: kept on the phone, sent once the connection returns',
    () async {
      final FakeRoute route = FakeRoute()..hold = Completer<void>();
      final JourneyTracker t = tracker(route: route);
      final JourneyModel j = await started();
      await t.start(j.id);
      fixAt(1, 0);
      fixAt(2, 30);
      await flush();

      await t.sync(); // waits AppDurations.syncWait, then counts it pending
      expect(t.current!.sync, RouteSync.pending);
      expect((await store.session('sara', j.id))!.syncedCount, 0);
      await t.sync();
      expect(route.uploads, hasLength(1));

      route.hold!.complete();
      await flush();
      expect((await store.session('sara', j.id))!.syncedCount, 2);
      expect(t.current!.sync, RouteSync.synced);
    },
  );

  test('a failed upload is tried again', () async {
    final FakeRoute route = FakeRoute()..failure = StateError('denied');
    final JourneyTracker t = tracker(route: route);
    final JourneyModel j = await started();
    await t.start(j.id);
    fixAt(1, 0);
    await flush();
    await t.sync();
    expect(t.current!.sync, RouteSync.failed);

    route.failure = null;
    await t.sync();
    expect(t.current!.sync, RouteSync.synced);
  });

  test('completing the journey stops the recording; the route stays', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    fixAt(1, 0);
    fixAt(2, 60);
    await flush();

    await journeys.complete(j.id);
    await flush();
    expect(t.current, isNull);
    expect(t.journeyId, isNull);
    final Map<String, dynamic> summary =
        (await db.doc('users/sara/journeys/${j.id}/tracking/summary').get())
            .data()!;
    expect(summary['recording'], isFalse);
    expect(summary['pointCount'], 2);
    expect(await store.session('sara', j.id), isNull);
    expect((await t.recorded(j.id))?.pointCount, 2);
    expect(await t.start(j.id), TrackStart.notActive);
    expect((await journeys.journey(j.id))!.status, JourneyStatus.completed);
  });

  test('after the app was closed it resumes, in a new segment', () async {
    final JourneyModel j = await started();
    final JourneyTracker first = tracker();
    await first.start(j.id);
    fixAt(1, 0);
    await flush();
    await first.dispose(); // the app is gone; nothing was stopped
    trackers.remove(first);

    location.fixesController = StreamController<LocationFix>.broadcast();
    final JourneyTracker second = tracker();
    now = now.add(const Duration(minutes: 5));
    await second.recover();
    expect(second.journeyId, j.id);
    fixAt(2, 800);
    await flush();

    final List<TrackPoint> points = await store.points('sara', j.id);
    expect(points.map((TrackPoint p) => p.segment), <int>[0, 1]);
    // No distance across the gap.
    expect(second.current!.distanceMeters, 0);
    expect((await journeys.journey(j.id))!.status, JourneyStatus.active);
  });

  test(
    'recovery sends what is left of a journey that ended meanwhile',
    () async {
      final JourneyModel j = await started();
      final JourneyTracker first = tracker(route: FakeRoute()..failure = 'off');
      await first.start(j.id);
      fixAt(1, 0);
      await flush();
      await first.dispose();
      trackers.remove(first);
      await journeys.complete(j.id);

      final JourneyTracker second = tracker();
      await second.recover();
      expect(second.journeyId, isNull);
      expect(await store.session('sara', j.id), isNull);
      final Map<String, dynamic> summary =
          (await db.doc('users/sara/journeys/${j.id}/tracking/summary').get())
              .data()!;
      expect(summary['recording'], isFalse);
      expect(summary['pointCount'], 1);
    },
  );

  test('signing out pauses; another account never resumes it', () async {
    final JourneyTracker t = tracker();
    final JourneyModel j = await started();
    await t.start(j.id);
    session.uid = 'omar';
    session.changed.add(null);
    await flush();
    expect(t.current, isNull);

    await t.recover();
    expect(t.journeyId, isNull);
    expect(await store.sessions('omar'), isEmpty);
    expect((await store.session('sara', j.id))!.recording, isTrue);
  });

  group('the incident observer', () {
    test('sees the same fixes as the tracker: one subscription', () async {
      final _Spy spy = _Spy();
      final JourneyTracker t = tracker(observer: spy);
      final JourneyModel j = await started();
      await t.start(j.id);
      fixAt(1, 0);
      fixAt(2, 30, accuracy: 120); // untrusted fixes reach it too
      await flush();
      t.tick();
      location.fixesController.addError(
        const LocationSourceError(LocationAccess.denied),
      );
      await flush();
      expect(location.listens, 1);
      expect(spy.calls, <String>[
        'started ${j.id}',
        'fixed',
        'fixed',
        'ticked',
        'interrupted permissionRemoved',
      ]);
    });

    test(
      'told when the journey ends, and when the account signs out',
      () async {
        final _Spy spy = _Spy();
        final JourneyTracker t = tracker(observer: spy);
        final JourneyModel a = await started('A');
        await t.start(a.id);
        await journeys.complete(a.id);
        await flush();
        expect(spy.calls.last, 'ended');

        final JourneyModel b = await started('B');
        await t.start(b.id);
        session.uid = 'omar';
        session.changed.add(null);
        await flush();
        expect(spy.calls.last, 'paused');
      },
    );

    test('a resumed recording passes when tracking last saw a fix', () async {
      final JourneyModel j = await started();
      final JourneyTracker first = tracker();
      await first.start(j.id);
      fixAt(1, 0);
      await flush();
      final DateTime lastFix = now;
      await first.dispose();
      trackers.remove(first);

      location.fixesController = StreamController<LocationFix>.broadcast();
      final _Spy spy = _Spy();
      now = now.add(const Duration(minutes: 5));
      await tracker(observer: spy).recover();
      expect(spy.lastFixBefore, lastFix);
    });

    test('standing still does not save the session on every fix', () async {
      final JourneyTracker t = tracker();
      final JourneyModel j = await started();
      await t.start(j.id);
      fixAt(1, 0);
      await flush();
      final int before = store.saves;
      for (int i = 0; i < 10; i++) {
        fixAt(i + 2, 0); // the same spot: no new point
        await flush();
      }
      expect(store.saves - before, lessThanOrEqualTo(1));
      expect((await store.points('sara', j.id)), hasLength(1));
    });
  });

  group('found in the final audit', () {
    test('a point the file lost never makes it send forever', () async {
      final FakeRoute route = FakeRoute();
      final JourneyTracker t = tracker(route: route);
      final JourneyModel j = await started();
      await t.start(j.id);
      fixAt(1, 0);
      await flush();
      fixAt(2, 20);
      await flush();
      fixAt(3, 40);
      await flush();
      store.loseLast('sara', j.id);

      await t.stop(j.id).timeout(const Duration(seconds: 5));

      expect(t.current, isNull);
      expect(route.uploads.length, lessThan(5));
      expect(route.uploads.last.summary.pointCount, 2);
      expect(await store.session('sara', j.id), isNull);
    });

    test('recovery of a recording that lost a point also ends', () async {
      final FakeRoute route = FakeRoute();
      final JourneyTracker first = tracker(route: route);
      final JourneyModel j = await started();
      await first.start(j.id);
      fixAt(1, 0);
      await flush();
      fixAt(2, 20);
      await flush();
      await first.dispose();
      trackers.remove(first);
      store.loseLast('sara', j.id);
      await journeys.complete(j.id);

      await tracker(route: route).recover().timeout(const Duration(seconds: 5));
      expect(await store.session('sara', j.id), isNull);
    });

    test('reopening never counts the gap, whatever fix comes first', () async {
      final JourneyTracker first = tracker(route: FakeRoute());
      final JourneyModel j = await started();
      await first.start(j.id);
      fixAt(1, 0);
      await flush();
      fixAt(2, 30);
      await flush();
      await first.dispose();
      trackers.remove(first);

      location.fixesController = StreamController<LocationFix>.broadcast();
      now = now.add(const Duration(hours: 1));
      final JourneyTracker second = tracker(route: FakeRoute());
      await second.start(j.id);
      fixAt(3, 40000, accuracy: 200); // Rejected, but it arrived.
      await flush();
      fixAt(4, 40000);
      await flush();

      expect(second.current!.distanceMeters, closeTo(30, 1));
      final List<TrackPoint> points = await store.points('sara', j.id);
      expect(points.last.segment, points.first.segment + 1);
    });

    test('a late old fix never moves the last fix back', () async {
      final JourneyTracker t = tracker(route: FakeRoute());
      final JourneyModel j = await started();
      await t.start(j.id);
      fixAt(1, 0);
      await flush();
      final DateTime newest = now;
      location.fix(24.7, 46.67, at: now.subtract(const Duration(seconds: 5)));
      await flush();
      fixAt(2, 0);
      await flush();
      expect(
        (await store.session('sara', j.id))!.lastFixAt!.isBefore(newest),
        isFalse,
      );
    });

    test('a start for another journey gets its own answer', () async {
      final JourneyTracker t = tracker(route: FakeRoute());
      final JourneyModel a = await started('Gym');
      final JourneyModel b = await started('Work');
      final List<TrackStart> both = await Future.wait(<Future<TrackStart>>[
        t.start(a.id),
        t.start(b.id),
      ]);
      expect(both, <TrackStart>[TrackStart.recording, TrackStart.otherJourney]);
      expect(t.journeyId, a.id);
    });

    test('stopping twice at once is harmless', () async {
      final JourneyTracker t = tracker(route: FakeRoute());
      final JourneyModel j = await started();
      await t.start(j.id);
      await Future.wait(<Future<void>>[t.stop(j.id), t.stop(j.id)]);
      expect(t.current, isNull);
    });

    test('a failed save never leaves the recording looking alive', () async {
      final JourneyTracker t = tracker(route: FakeRoute());
      final JourneyModel a = await started('Gym');
      await t.start(a.id);
      store.failure = StateError('disk full');
      await t.stop(a.id);
      expect(t.current, isNull);
      expect(t.journeyId, isNull);

      store.failure = null;
      final JourneyModel b = await started('Work');
      expect(await t.start(b.id), TrackStart.recording);
    });

    test('recovering twice at once finishes a recording once', () async {
      final FakeRoute route = FakeRoute();
      final JourneyTracker first = tracker(route: route);
      final JourneyModel j = await started();
      await first.start(j.id);
      fixAt(1, 0);
      await flush();
      await first.dispose();
      trackers.remove(first);
      await journeys.complete(j.id);
      route.uploads.clear();

      final JourneyTracker t = tracker(route: route);
      await Future.wait(<Future<void>>[t.recover(), t.recover()]);
      expect(route.uploads, hasLength(1));
    });

    test('the next account sees no speed of the last, and syncs', () async {
      final FakeRoute route = FakeRoute()..hold = Completer<void>();
      final JourneyTracker t = tracker(route: route);
      final JourneyModel a = await started('Gym');
      await t.start(a.id);
      fixAt(1, 0, speed: 20);
      await flush();
      fixAt(2, 30, speed: 20);
      await flush();
      // Offline: a chunk waits for this account.
      final Future<void> waiting = t.sync();
      await waiting.timeout(const Duration(seconds: 10), onTimeout: () {});

      session
        ..uid = null
        ..changed.add(null);
      await flush();
      expect(t.current, isNull);

      session
        ..uid = 'omar'
        ..changed.add(null);
      await flush();
      route.hold = null;
      final JourneyModel b = await started('Work');
      expect(await t.start(b.id), TrackStart.recording);
      expect(t.current?.speed.kmh, isNull);
      fixAt(3, 0);
      await flush();
      final int before = route.uploads.length;
      await t.sync();
      expect(route.uploads.length, greaterThan(before));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('discarding stops without sending or finishing', () async {
      final FakeRoute route = FakeRoute();
      final _Spy spy = _Spy();
      final JourneyTracker t = tracker(route: route, observer: spy);
      final JourneyModel j = await started();
      await t.start(j.id);
      fixAt(1, 0);
      await flush();
      route.uploads.clear();
      await t.discard();
      expect(t.current, isNull);
      expect(route.uploads, isEmpty);
      expect(spy.calls, contains('paused'));
      expect(spy.calls, isNot(contains('ended')));
      await t.discard();
    });
  });
}
