import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/tracker_position_reader.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

/// The emergency screens' view of where the user is, over the real tracker:
/// it reads, never asks, and never takes a reading unless told to.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreJourneyRepository journeys;
  late FakeLocation location;
  late JourneyTracker tracker;
  late TrackerPositionReader reader;

  setUp(() {
    db = FakeFirebaseFirestore();
    journeys = FirestoreJourneyRepository(db, _Session());
    location = FakeLocation(now: LocationAccess.granted);
    tracker = JourneyTracker(
      location: location,
      store: MemoryTrackStore(),
      route: FirestoreRouteRepository(db, _Session()),
      journeys: journeys,
      session: _Session(),
      translate: (String key) => key,
      tickEvery: const Duration(days: 1),
    );
    reader = TrackerPositionReader(tracker, journeys);
  });

  tearDown(() => tracker.dispose());

  Future<JourneyModel> started(String to) async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: to,
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await journeys.start(
      j.id,
      checklistVersion: JourneyChecklist.current,
      confirmed: JourneyChecklist.itemsOf(JourneyChecklist.current).toSet(),
    );
    return j;
  }

  test('nothing recorded, no journey: no location and no journey, and no '
      'reading taken', () async {
    final EmergencyPosition p = await reader.lastKnown();
    expect(p.access, PositionAccess.allowed);
    expect(p.reading, isNull);
    expect(p.destination, isNull);
    expect(location.oneOffs, 0);
    expect(location.asked, 0);
  });

  for (final (LocationAccess access, PositionAccess shown)
      in <(LocationAccess, PositionAccess)>[
        (LocationAccess.denied, PositionAccess.notAllowed),
        (LocationAccess.deniedForever, PositionAccess.notAllowed),
        (LocationAccess.serviceOff, PositionAccess.servicesOff),
      ]) {
    test('${access.name}: said as ${shown.name}; Find my location neither asks '
        'nor reads', () async {
      location.now = access;
      final EmergencyPosition p = await reader.locateNow();
      expect(p.access, shown);
      expect(p.reading, isNull);
      expect(location.asked, 0, reason: 'never a permission prompt');
      expect(location.oneOffs, 0);
    });
  }

  test('approximate only: read, and said to be approximate', () async {
    location
      ..now = LocationAccess.approximate
      ..oneOff = LocationFix(
        latitude: 24.71,
        longitude: 46.67,
        at: DateTime.now().toUtc(),
        accuracy: 2400,
      );
    final EmergencyPosition p = await reader.locateNow();
    expect(p.access, PositionAccess.approximate);
    expect(p.reading?.quality, PositionAccuracy.poor);
  });

  test('Find my location: one reading, on the tap only', () async {
    final DateTime at = DateTime.now().toUtc();
    location.oneOff = LocationFix(
      latitude: 24.7136,
      longitude: 46.6753,
      at: at,
      accuracy: 0,
    );
    final EmergencyPosition p = await reader.locateNow();
    expect(location.oneOffs, 1);
    expect(p.reading?.latitude, 24.7136);
    expect(p.reading?.at, at);
    expect(p.reading?.accuracy, isNull, reason: '0 means unknown');
    expect(await reader.lastKnown().then((p) => p.reading), isNull);
  });

  test('a broken 0,0 fix is never shown as a location', () async {
    location.oneOff = LocationFix(
      latitude: 0,
      longitude: 0,
      at: DateTime.now().toUtc(),
      accuracy: 5,
    );
    expect((await reader.locateNow()).reading, isNull);
  });

  test('a journey in progress: its destination, and the recording\'s last '
      'fix as the last known location', () async {
    final JourneyModel j = await started('King Fahd Hospital');
    await tracker.start(j.id);
    final DateTime at = DateTime.now().toUtc();
    location.fix(24.7136, 46.6753, at: at, accuracy: 12);
    await pumpEventQueue(times: 100);

    final EmergencyPosition p = await reader.lastKnown();
    expect(p.destination, 'King Fahd Hospital');
    expect(p.reading?.latitude, 24.7136);
    expect(p.reading?.accuracy, 12);
    expect(p.reading?.at, at);
    expect(location.oneOffs, 0);
  });

  test('a planned journey is not one in progress', () async {
    await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect((await reader.lastKnown()).destination, isNull);
  });
}
