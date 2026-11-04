import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_monitor.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';

import '../tracking_fakes.dart';

/// Feeds a monitor the way the tracker does: a fix every 2 s.
class _Feed {
  _Feed(this.monitor, {this.journeyId = 'j1'}) {
    monitor.started('sara', journeyId, now);
  }

  final IncidentMonitor monitor;
  final String journeyId;
  DateTime now = DateTime.utc(2026, 11, 3, 9);
  double metres = 0;

  void fix(double speed, {double? moved, double accuracy = 5}) {
    now = now.add(const Duration(seconds: 2));
    metres += moved ?? speed * 2;
    monitor.fixed(
      journeyId,
      LocationFix(
        latitude: 24.712345678 + metres / 111195,
        longitude: 46.676543219,
        at: now,
        accuracy: accuracy,
        speed: speed,
        speedAccuracy: 0.5,
      ),
      now,
    );
  }

  void cruise(double speed, double seconds) {
    for (double t = 0; t < seconds; t += 2) {
      fix(speed);
    }
  }

  void still(double seconds) {
    for (double t = 0; t < seconds; t += 2) {
      fix(0.2, moved: 0);
    }
  }

  /// A hard stop from 15 m/s that lasts.
  void suddenStop() {
    cruise(15, 12);
    fix(0.5, moved: 15.5);
    still(16);
  }
}

void main() {
  late MemoryIncidentRepository store;
  late IncidentMonitor monitor;

  setUp(() {
    store = MemoryIncidentRepository();
    monitor = IncidentMonitor(store);
  });

  Future<List<PotentialIncident>> events([String journeyId = 'j1']) async {
    await monitor.idle;
    return store.forJourney('sara', journeyId);
  }

  test('a sudden stop is stored once, with what the data showed', () async {
    final _Feed f = _Feed(monitor)
      ..suddenStop()
      ..still(30);
    final PotentialIncident e = (await events()).single;
    expect(e.type, IncidentType.suddenDeceleration);
    expect(e.status, IncidentStatus.detected);
    expect(e.confidence, IncidentConfidence.high);
    expect(e.journeyId, 'j1');
    expect(e.uid, 'sara');
    expect(e.speedBeforeKmh, closeTo(54, 0.01));
    expect(e.speedAfterKmh, closeTo(1.8, 0.01));
    expect(e.accuracyMeters, 5);
    expect(e.reason, contains('m/s²'));
    // About 11 m: four decimals, never the full precision.
    expect(e.lng, 46.6765);
    expect(e.lat! * 10000, closeTo((e.lat! * 10000).roundToDouble(), 1e-6));
    expect(
      e.detectedAt.isAfter(f.now.subtract(const Duration(minutes: 1))),
      isTrue,
    );
  });

  test('a long stop after it replaces it, with more confidence', () async {
    _Feed(monitor)
      ..suddenStop()
      ..still(300);
    final List<PotentialIncident> all = await events();
    expect(all, hasLength(2));
    final PotentialIncident deceleration = all.first;
    final PotentialIncident stop = all.last;
    expect(deceleration.status, IncidentStatus.superseded);
    expect(deceleration.supersededBy, stop.id);
    expect(deceleration.resolution, IncidentResolution.replaced);
    expect(stop.type, IncidentType.prolongedStop);
    expect(stop.status, IncidentStatus.detected);
    expect(stop.confidence, IncidentConfidence.high);
  });

  test('moving again resolves it', () async {
    _Feed(monitor)
      ..suddenStop()
      ..cruise(8, 10);
    final PotentialIncident e = (await events()).single;
    expect(e.status, IncidentStatus.resolved);
    expect(e.resolution, IncidentResolution.movementResumed);
  });

  test(
    'the journey ending resolves what is open, and stops watching',
    () async {
      final _Feed f = _Feed(monitor)..suddenStop();
      monitor.ended('sara', 'j1', f.now);
      f
        ..cruise(15, 12)
        ..fix(0.5, moved: 15.5)
        ..still(30);
      final List<PotentialIncident> all = await events();
      expect(all, hasLength(1));
      expect(all.single.status, IncidentStatus.resolved);
      expect(all.single.resolution, IncidentResolution.journeyEnded);
    },
  );

  test('a new journey starts fresh; the old one cannot reach it', () async {
    final _Feed a = _Feed(monitor)..suddenStop();
    monitor.ended('sara', 'j1', a.now);
    final _Feed b = _Feed(monitor, journeyId: 'j2')..still(400);
    // Fixes addressed to the old journey are ignored.
    monitor.fixed(
      'j1',
      LocationFix(latitude: 24.7, longitude: 46.6, at: b.now, accuracy: 5),
      b.now,
    );
    expect(await events('j2'), isEmpty, reason: 'j2 never moved');
    expect((await events('j1')).single.status, IncidentStatus.resolved);
  });

  test('signed out: nothing more is watched', () async {
    final _Feed f = _Feed(monitor)..cruise(15, 12);
    monitor.paused('j1');
    f
      ..fix(0.5, moved: 15.5)
      ..still(30);
    expect(await events(), isEmpty);
  });

  test('a new interruption cause replaces the old one', () async {
    final _Feed f = _Feed(monitor)..cruise(15, 6);
    monitor
      ..interrupted('j1', InterruptionCause.permissionRemoved, f.now)
      ..interrupted('j1', InterruptionCause.locationServicesOff, f.now);
    final List<PotentialIncident> all = await events();
    expect(all.map((PotentialIncident i) => i.status), <IncidentStatus>[
      IncidentStatus.superseded,
      IncidentStatus.detected,
    ]);
    expect(all.last.interruption, InterruptionCause.locationServicesOff);
    expect(all.last.confidence, IncidentConfidence.low);
    f.fix(15, moved: 30);
    expect((await events()).last.status, IncidentStatus.resolved);
  });

  test('after an app restart the events are still there', () async {
    final Directory root = await Directory.systemTemp.createTemp('incidents');
    addTearDown(() => root.delete(recursive: true));
    final IncidentRepository disk = FileIncidentRepository(
      root: () async => root,
    );
    final IncidentMonitor first = IncidentMonitor(disk);
    final _Feed f = _Feed(first)..suddenStop();
    await first.idle;

    // The app restarts: new objects, the same files.
    final IncidentRepository reopened = FileIncidentRepository(
      root: () async => root,
    );
    final List<PotentialIncident> kept = await reopened.forJourney(
      'sara',
      'j1',
    );
    expect(kept.single.type, IncidentType.suddenDeceleration);
    final IncidentMonitor second = IncidentMonitor(reopened)
      ..started('sara', 'j1', f.now, lastFixBefore: f.now)
      ..ended('sara', 'j1', f.now);
    await second.idle;
    expect(
      (await reopened.forJourney('sara', 'j1')).single.status,
      IncidentStatus.resolved,
    );
  });

  group('the file store', () {
    late Directory root;
    late FileIncidentRepository repo;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('incidents');
      repo = FileIncidentRepository(root: () async => root);
    });
    tearDown(() => root.delete(recursive: true));

    PotentialIncident event(int i, {String uid = 'sara', String j = 'j1'}) =>
        PotentialIncident(
          id: '$j-$i',
          journeyId: j,
          uid: uid,
          type: IncidentType.prolongedStop,
          status: i.isEven ? IncidentStatus.resolved : IncidentStatus.detected,
          confidence: IncidentConfidence.medium,
          detectedAt: DateTime.utc(2026, 11, 3, 9, 0, i),
          updatedAt: DateTime.utc(2026, 11, 3, 9, 0, i),
          reason: 'test',
        );

    test('replaces by id; each account sees only its own', () async {
      await repo.put(event(1));
      await repo.put(event(1).copyWith(status: IncidentStatus.dismissed));
      await repo.put(event(2, uid: 'omar'));
      expect(
        (await repo.forJourney('sara', 'j1')).single.status,
        IncidentStatus.dismissed,
      );
      expect(await repo.forJourney('omar', 'j9'), isEmpty);
    });

    test('keeps the newest hundred, closed ones dropped first', () async {
      for (int i = 0; i < FileIncidentRepository.keep + 10; i++) {
        await repo.put(event(i));
      }
      final List<PotentialIncident> kept = await repo.forJourney('sara', 'j1');
      expect(kept, hasLength(FileIncidentRepository.keep));
      expect(
        kept.where(
          (PotentialIncident i) => i.status == IncidentStatus.detected,
        ),
        hasLength(55),
      );
    });

    test('a damaged file reads as nothing, and is replaced', () async {
      await File(
        '${root.path}/incidents/sara.json',
      ).create(recursive: true).then((File f) => f.writeAsString('[{"id":'));
      expect(await repo.forJourney('sara', 'j1'), isEmpty);
      await repo.put(event(1));
      expect(await repo.forJourney('sara', 'j1'), hasLength(1));
    });
  });

  test('an event left open by the last run never swallows a new one', () async {
    final _Feed first = _Feed(monitor)..suddenStop();
    await monitor.idle;
    final PotentialIncident left = (await events()).single;
    expect(left.status, IncidentStatus.detected);

    // The app was closed: a new monitor, a new engine, the same journey.
    final IncidentMonitor second = IncidentMonitor(store);
    final _Feed next = _Feed(second)..now = first.now;
    next.suddenStop();
    await second.idle;

    final List<PotentialIncident> all = await events();
    expect(all, hasLength(2));
    expect(all.first.status, IncidentStatus.superseded);
    expect(all.last.status, IncidentStatus.detected);
  });
}
