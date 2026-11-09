import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_picker_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_search_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/route_preview_cubit.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

const JourneyPlace _mall = JourneyPlace(name: 'Mall', lat: 24.7, lng: 46.7);

void main() {
  group('PlaceSearchCubit', () {
    test('asks once, after the typing stops', () {
      fakeAsync((FakeAsync async) {
        final FakeGeocoding geo = FakeGeocoding()
          ..results = <JourneyPlace>[_mall];
        final PlaceSearchCubit cubit = PlaceSearchCubit(geo);
        for (final String text in <String>['Mal', 'Mall', 'Mall o']) {
          cubit.query(text, languageCode: 'en');
          async.elapse(const Duration(milliseconds: 200));
        }
        expect(geo.searches, isEmpty);
        expect(cubit.state.status, PlaceSearchStatus.searching);
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(geo.searches, <String>['Mall o']);
        expect(cubit.state.status, PlaceSearchStatus.results);
        expect(cubit.state.places, <JourneyPlace>[_mall]);
        cubit.close();
      });
    });

    test('short words ask nothing', () {
      fakeAsync((FakeAsync async) {
        final FakeGeocoding geo = FakeGeocoding();
        final PlaceSearchCubit cubit = PlaceSearchCubit(geo);
        cubit.query(' a ', languageCode: 'en');
        async.elapse(const Duration(seconds: 2));
        expect(geo.searches, isEmpty);
        expect(cubit.state.status, PlaceSearchStatus.idle);
        cubit.close();
      });
    });

    test('a newer search aborts the older, whose answer is dropped', () {
      fakeAsync((FakeAsync async) {
        final Completer<void> hold = Completer<void>();
        final FakeGeocoding geo = FakeGeocoding()
          ..hold = hold
          ..results = <JourneyPlace>[_mall];
        final PlaceSearchCubit cubit = PlaceSearchCubit(geo);
        cubit.query('first', languageCode: 'en');
        async.elapse(const Duration(milliseconds: 600));
        cubit.query('second', languageCode: 'en');
        async.flushMicrotasks();
        expect(geo.cancelled, isTrue);
        hold.complete();
        async.flushMicrotasks();
        expect(cubit.state.status, PlaceSearchStatus.searching);
        cubit.close();
      });
    });

    test('nothing found, and failing, are different', () {
      fakeAsync((FakeAsync async) {
        final FakeGeocoding geo = FakeGeocoding();
        final PlaceSearchCubit cubit = PlaceSearchCubit(geo);
        cubit.query('zzzz', languageCode: 'en');
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.status, PlaceSearchStatus.empty);

        geo.failure = const MapFailure(MapFailureCode.offline);
        cubit.query('yyyy', languageCode: 'en');
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.status, PlaceSearchStatus.failed);
        expect(cubit.state.failure, MapFailureCode.offline);
        cubit.close();
      });
    });

    test('clearing stops what was waiting', () {
      fakeAsync((FakeAsync async) {
        final FakeGeocoding geo = FakeGeocoding();
        final PlaceSearchCubit cubit = PlaceSearchCubit(geo);
        cubit.query('Mall', languageCode: 'en');
        cubit.clear();
        async.elapse(const Duration(seconds: 1));
        expect(geo.searches, isEmpty);
        expect(cubit.state.status, PlaceSearchStatus.idle);
        cubit.close();
      });
    });
  });

  group('PlacePickerCubit', () {
    late FakeGeocoding geo;
    late FakeLocation location;
    late JourneyTracker tracker;

    setUp(() {
      geo = FakeGeocoding();
      location = FakeLocation(now: LocationAccess.granted);
      final _Session session = _Session();
      tracker = JourneyTracker(
        location: location,
        store: MemoryTrackStore(),
        route: FakeRoute(),
        journeys: FirestoreJourneyRepository(FakeFirebaseFirestore(), session),
        session: session,
        translate: (String k) => k,
      );
    });

    tearDown(() => tracker.dispose());

    PlacePickerCubit cubit() =>
        PlacePickerCubit(geo, tracker, settle: const Duration(milliseconds: 1));

    Future<void> rest() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('a pin is named once it rests; the pin stays put', () async {
      geo.named = const JourneyPlace(name: 'Olaya', lat: 24.9, lng: 46.9);
      final PlacePickerCubit c = cubit();
      c.moved(const LatLng(24.7, 46.7), languageCode: 'en');
      expect(c.state.naming, isTrue);
      await rest();
      expect(c.state.place?.name, 'Olaya');
      expect(c.state.place?.lat, 24.7, reason: 'where the user put it');
      await c.close();
    });

    test('dragging asks only for where it stopped', () async {
      final PlacePickerCubit c = PlacePickerCubit(
        geo,
        tracker,
        settle: const Duration(milliseconds: 15),
      );
      for (double i = 0; i < 5; i++) {
        c.moved(LatLng(24.7 + i / 100, 46.7), languageCode: 'en');
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(geo.reverses, 1);
      await c.close();
    });

    test('offline, a pin is still a pin', () async {
      geo.failure = const MapFailure(MapFailureCode.offline);
      final PlacePickerCubit c = cubit();
      c.moved(const LatLng(24.7, 46.7), languageCode: 'en');
      await rest();
      expect(c.state.point, const LatLng(24.7, 46.7));
      expect(c.state.place, isNull);
      expect(c.state.naming, isFalse);
      await c.close();
    });

    test('impossible coordinates are ignored', () async {
      final PlacePickerCubit c = cubit();
      c.moved(const LatLng(0, 0), languageCode: 'en');
      expect(c.state.point, isNull);
      await c.close();
    });

    test('a search result needs no naming', () async {
      final PlacePickerCubit c = cubit();
      c.picked(_mall);
      await rest();
      expect(c.state.place, _mall);
      expect(geo.reverses, 0);
      await c.close();
    });

    test('"Use my location" takes one reading, no subscription', () async {
      location.oneOff = LocationFix(
        latitude: 24.7,
        longitude: 46.7,
        at: DateTime.now().toUtc(),
        accuracy: 8,
      );
      final PlacePickerCubit c = cubit();
      await c.locate(languageCode: 'en');
      await rest();
      expect(c.state.point, const LatLng(24.7, 46.7));
      expect(location.oneOffs, 1);
      expect(location.listens, 0);
      await c.close();
    });

    test('permission is asked only from that tap, and a no is said', () async {
      location
        ..now = LocationAccess.denied
        ..afterAsking = LocationAccess.deniedForever;
      final PlacePickerCubit c = cubit();
      expect(location.asked, 0);
      await c.locate(languageCode: 'en');
      expect(location.asked, 1);
      expect(c.state.locationProblem, LocationAccess.deniedForever);
      expect(c.state.locating, isFalse);
      await c.close();
    });

    test('no reading in time is said, and any pin stays', () async {
      final PlacePickerCubit c = cubit();
      c.picked(_mall);
      await c.locate(languageCode: 'en');
      expect(c.state.locationProblem, LocationAccess.serviceOff);
      expect(c.state.point, _mall.point);
      await c.close();
    });
  });

  group('RoutePreviewCubit', () {
    const LatLng a = LatLng(24.7, 46.7);
    const LatLng b = LatLng(24.8, 46.8);
    const PlannedRoute route = PlannedRoute(
      points: <LatLng>[a, b],
      distanceMeters: 1500,
      durationSeconds: 240,
    );

    test('waits for both places', () async {
      final FakeRouting routing = FakeRouting()..answer = route;
      final RoutePreviewCubit c = RoutePreviewCubit(routing);
      await c.update(a, null);
      expect(routing.asked, 0);
      expect(c.state.route, isNull);
      await c.update(a, b);
      expect(c.state.route, route);
      await c.close();
    });

    test('the same places are not asked for again', () async {
      final FakeRouting routing = FakeRouting()..answer = route;
      final RoutePreviewCubit c = RoutePreviewCubit(routing);
      await c.update(a, b);
      await c.update(a, b);
      expect(routing.asked, 1);
      await c.close();
    });

    test('a failure says why, and retrying can work', () async {
      final FakeRouting routing = FakeRouting()
        ..failure = const MapFailure(MapFailureCode.offline);
      final RoutePreviewCubit c = RoutePreviewCubit(routing);
      await c.update(a, b);
      expect(c.state.failure, MapFailureCode.offline);
      expect(c.state.route, isNull);
      routing.answer = route;
      await c.retry();
      expect(c.state.route, route);
      expect(c.state.failure, isNull);
      await c.close();
    });

    test('clearing a place clears the route', () async {
      final RoutePreviewCubit c = RoutePreviewCubit(
        FakeRouting()..answer = route,
      );
      await c.update(a, b);
      await c.update(null, b);
      expect(c.state, const RoutePreviewState());
      await c.close();
    });
  });
}
