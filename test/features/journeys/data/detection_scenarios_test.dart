import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_detection_engine.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_monitor.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';

import '../simulation/gps_script.dart';
import '../tracking_fakes.dart';

/// Replays a synthetic journey into a fresh engine and records what it
/// concludes.
EngineRecorder replay(GpsScript s, {IncidentPlace? destination}) {
  final EngineRecorder r = EngineRecorder(destination: destination);
  s.play(r);
  return r;
}

const Duration _s = Duration(seconds: 1);
const Duration _min = Duration(minutes: 1);

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

/// The intended behaviour of detection on ordinary and unusual driving, as
/// deterministic replays. Each scenario says what must, and must not, happen.
void main() {
  group('ordinary driving asks nothing', () {
    test('1. normal uninterrupted driving', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(50, _min * 2)
          ..turn(90)
          ..drive(60, _min * 3)
          ..brake(0, 2.5)
          ..hold(_s * 20)
          ..accelerate(50, 3)
          ..drive(50, _min),
      );
      expect(r.signals, isEmpty);
    });

    test('2. normal gradual braking to a stop', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(70, _min * 2)
          ..brake(0, 2.5)
          ..hold(_min * 3)
          ..accelerate(50, 2)
          ..drive(50, _min),
      );
      expect(r.movement, isEmpty);
    });

    test('3. sudden braking without an accident: a hard stop, then green', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(50, _min)
          // 50 km/h to nothing between two fixes: 6.9 m/s².
          ..drop(0)
          ..hold(_s * 40)
          ..accelerate(50, 2.5)
          ..drive(50, _min),
      );
      expect(r.movement, isEmpty, reason: 'the light turned green in time');
    });

    test('3b. a hard stop into a crawling queue is traffic', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(50, _min)
          ..drop(0)
          ..hold(_s * 6)
          ..crawl(5, _s * 20)
          ..hold(_s * 30)
          ..crawl(5, _s * 20),
      );
      expect(r.movement, isEmpty);
    });

    test('4. a speed bump', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(40, _s * 30)
          ..brake(10, 3)
          ..accelerate(40, 2)
          ..drive(40, _s * 30),
      );
      expect(r.signals, isEmpty);
    });

    test('5. a sharp turn', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(50, _s * 30)
          ..brake(20, 3)
          ..turn(90)
          ..drive(20, _s * 6)
          ..accelerate(50, 2)
          ..drive(50, _s * 30),
      );
      expect(r.signals, isEmpty);
    });

    test('6. stop-and-go traffic, for ten minutes', () {
      final GpsScript s = GpsScript()..drive(60, _min);
      for (int i = 0; i < 5; i++) {
        s
          ..accelerate(30, 2.5)
          ..drive(30, _s * 10)
          ..brake(0, 3)
          ..hold(_s * 20)
          ..crawl(5, _s * 10)
          ..hold(_s * 20);
      }
      // A long jam: barely moving, but moving, for six minutes.
      s
        ..hold(_s * 90)
        ..crawl(4, _s * 6)
        ..hold(_s * 90)
        ..crawl(4, _s * 6)
        ..hold(_s * 200);
      final EngineRecorder r = replay(s);
      expect(r.asks, isEmpty, reason: 'nothing asks "Are you okay?"');
      expect(
        r.movement.every(
          (IncidentSignal x) => x.confidence == IncidentConfidence.low,
        ),
        isTrue,
      );
    });

    test('7. a traffic-light stop', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(60, _min)
          ..brake(0, 3)
          ..hold(_s * 90)
          ..accelerate(60, 2.5)
          ..drive(60, _min),
      );
      expect(r.signals, isEmpty);
    });

    test(
      '8. a long stop at the destination has arrived: kept, never asked',
      () {
        final GpsScript s = GpsScript()
          ..drive(50, _min * 3)
          ..brake(0, 3);
        final IncidentPlace there = (latitude: s.lat, longitude: s.lng);
        s.hold(_min * 6);
        final EngineRecorder r = replay(s, destination: there);
        expect(r.asks, isEmpty);
        expect(
          r.movement.single.confidence,
          IncidentConfidence.low,
          reason: 'stored, for the record',
        );
      },
    );
  });

  group('unusual movement is still noticed', () {
    test('8b. five minutes still mid-journey asks, at medium', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(50, _min * 3)
          ..brake(0, 3)
          ..hold(_min * 6),
      );
      final IncidentSignal stop = r.asks.single;
      expect(stop.type, IncidentType.prolongedStop);
      expect(stop.confidence, IncidentConfidence.medium);
    });

    test('9. a sudden deceleration with supporting evidence: high at 15 s, '
        'then a high stop', () {
      final GpsScript s = GpsScript()
        ..drive(60, _min)
        ..drop(0);
      final DateTime dropAt = s.now;
      s.hold(_min * 6);
      final EngineRecorder r = replay(s);
      final IncidentSignal first = r.asks.first;
      expect(first.type, IncidentType.suddenDeceleration);
      expect(first.confidence, IncidentConfidence.high);
      expect(first.at.difference(dropAt), lessThanOrEqualTo(_s * 16));
      expect(r.asks.last.type, IncidentType.prolongedStop);
      expect(r.asks.last.confidence, IncidentConfidence.high);
    });

    test('9b. the same drop with weaker data waits 45 s, then medium', () {
      final GpsScript s = GpsScript();
      s.reporting(
        unknownSpeedError: true,
        accuracy: 12,
        steps: (GpsScript g) => g
          ..drive(60, _min)
          ..drop(0)
          ..hold(_s * 50),
      );
      final EngineRecorder r = replay(s);
      final IncidentSignal d = r.asks.single;
      expect(d.confidence, IncidentConfidence.medium);
      expect(d.duration, greaterThanOrEqualTo(_s * 45));
    });

    test('9c. an emergency stop held beyond 15 s still asks: GPS cannot '
        'tell it from a collision, so the user is the one to say', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(60, _min)
          ..drop(0)
          ..hold(_s * 20)
          ..accelerate(50, 2.5)
          ..drive(50, _s * 30),
      );
      expect(r.asks.single.confidence, IncidentConfidence.high);
      expect(r.cleared.single.resolution, IncidentResolution.movementResumed);
    });
  });

  group('bad data never makes an event', () {
    test('10. a coordinate jump while waiting does not arm the stop', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..hold(_min * 2)
          ..jump(300)
          ..hold(_min * 8),
      );
      expect(r.movement, isEmpty, reason: 'it never set off');
    });

    test('10b. one jump neither ends an open stop nor starts a second one', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(50, _min * 3)
          ..brake(0, 3)
          ..hold(_min * 6)
          ..jump(200)
          ..hold(_min * 6),
      );
      expect(r.movement, hasLength(1));
      expect(r.cleared, isEmpty);
    });

    test('10c. one jump during a drop\'s wait does not cancel it', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(60, _min)
          ..drop(0)
          ..hold(_s * 6)
          ..jump(100)
          ..hold(_s * 14),
      );
      expect(r.asks.single.type, IncidentType.suddenDeceleration);
    });

    test('11. poor accuracy: nothing above low, ever', () {
      final GpsScript s = GpsScript();
      s.reporting(
        accuracy: 18,
        steps: (GpsScript g) => g
          ..drive(60, _min)
          ..drop(0)
          ..hold(_min * 6),
      );
      final EngineRecorder r = replay(s);
      expect(r.asks, isEmpty);
      expect(r.movement, isNotEmpty);
    });

    test(
      '11b. accuracy too poor to use reads as no signal, never movement',
      () {
        final GpsScript s = GpsScript();
        s.reporting(
          accuracy: 40,
          steps: (GpsScript g) => g
            ..drive(60, _min)
            ..drop(0)
            ..hold(_min * 6),
        );
        final EngineRecorder r = replay(s);
        expect(r.movement, isEmpty);
        expect(
          r.interruptions.single.interruption,
          InterruptionCause.signalLost,
        );
        expect(r.interruptions.single.confidence, IncidentConfidence.low);
      },
    );

    test('12. a stale fix showing a stop is ignored', () {
      final GpsScript s = GpsScript()..drive(60, _min);
      s.speed = 0;
      s.stale(_s * 20);
      s.speed = GpsScript.ms(60);
      s.drive(60, _min);
      expect(replay(s).signals, isEmpty);
    });

    test('12b. a whole drop that arrives stale cannot make an event', () {
      final GpsScript fresh = GpsScript()..drive(60, _min);
      final EngineRecorder r = EngineRecorder();
      fresh.play(r);
      // The same stop, every fix 15 s old on arrival.
      final GpsScript late = GpsScript(start: fresh.now)
        ..speed = GpsScript.ms(60)
        ..drop(0)
        ..hold(_s * 30);
      for (final ScriptEvent e in late.events) {
        if (e case ScriptedFix(:final fix, :final arrives)) {
          r.fixed('j1', fix, arrives.add(_s * 15));
        }
      }
      expect(r.movement, isEmpty);
    });

    test('13. missing speed is never read as a crash', () {
      final GpsScript s = GpsScript();
      s.reporting(
        speed: false,
        steps: (GpsScript g) => g
          ..drive(60, _min)
          ..drop(0)
          ..hold(_s * 40),
      );
      expect(replay(s).movement, isEmpty);
    });

    test('13b. without speed, a long stop is still seen by position', () {
      final GpsScript s = GpsScript();
      s.reporting(
        speed: false,
        steps: (GpsScript g) => g
          ..drive(50, _min * 3)
          ..brake(0, 3)
          ..hold(_min * 6),
      );
      final EngineRecorder r = replay(s);
      expect(r.movement.single.type, IncidentType.prolongedStop);
      expect(
        r.movement.any(
          (IncidentSignal x) => x.type == IncidentType.suddenDeceleration,
        ),
        isFalse,
      );
    });

    test('14. repeated timestamps change nothing', () {
      GpsScript build({required bool repeats}) {
        final GpsScript s = GpsScript()..drive(60, _s * 30);
        s.drop(0);
        if (repeats) s.repeat();
        for (int i = 0; i < 10; i++) {
          s.hold(_s * 2);
          if (repeats) s.repeat();
        }
        return s;
      }

      final List<IncidentSignal> clean = replay(build(repeats: false)).signals;
      final List<IncidentSignal> repeated = replay(
        build(repeats: true),
      ).signals;
      expect(clean, hasLength(1));
      expect(
        repeated.map(
          (IncidentSignal x) => (x.type, x.confidence, x.at, x.reason),
        ),
        clean.map((IncidentSignal x) => (x.type, x.confidence, x.at, x.reason)),
      );
    });

    test('15. out-of-order fixes are ignored, and time never goes back', () {
      GpsScript build({required bool late}) {
        final GpsScript s = GpsScript()
          ..drive(50, _min * 3)
          ..brake(0, 3);
        for (int i = 0; i < 20; i++) {
          s.hold(_s * 18);
          if (late) s.late(_s * 6);
        }
        return s;
      }

      final List<IncidentSignal> clean = replay(build(late: false)).signals;
      final List<IncidentSignal> mixed = replay(build(late: true)).signals;
      expect(clean.single.type, IncidentType.prolongedStop);
      expect(
        mixed.map((IncidentSignal x) => (x.type, x.confidence, x.at)),
        clean.map((IncidentSignal x) => (x.type, x.confidence, x.at)),
      );
    });

    test('16. a short GPS gap is nothing; a long one is a low interruption, '
        'cleared when fixes return', () {
      final EngineRecorder short = replay(
        GpsScript()
          ..drive(60, _min)
          ..gap(_s * 30)
          ..drive(60, _min),
      );
      expect(short.signals, isEmpty);

      final EngineRecorder long = replay(
        GpsScript()
          ..drive(60, _min)
          ..gap(_s * 90)
          ..drive(60, _min),
      );
      expect(long.movement, isEmpty);
      expect(
        long.interruptions.single.interruption,
        InterruptionCause.signalLost,
      );
      expect(
        long.cleared.single.resolution,
        IncidentResolution.trackingRestored,
      );
    });
  });

  group('interruptions are never movement', () {
    void cut(EngineRecorder r, InterruptionCause cause, DateTime at) =>
        r.interrupted('j1', cause, at);

    test(
      '17. permission revoked mid-drop: low, and the drop is not concluded',
      () {
        final GpsScript before = GpsScript()
          ..drive(60, _min)
          ..drop(0)
          ..hold(_s * 6);
        final EngineRecorder r = replay(before);
        cut(r, InterruptionCause.permissionRemoved, before.now);
        final GpsScript after = GpsScript(start: before.now)
          ..lat = before.lat
          ..lng = before.lng
          ..hold(_s * 60);
        after.play(r, start: false);
        expect(r.movement, isEmpty);
        expect(
          r.interruptions.single.interruption,
          InterruptionCause.permissionRemoved,
        );
        expect(r.interruptions.single.confidence, IncidentConfidence.low);
      },
    );

    test('18. location services off, then on again', () {
      final GpsScript before = GpsScript()..drive(60, _min);
      final EngineRecorder r = replay(before);
      cut(r, InterruptionCause.locationServicesOff, before.now);
      cut(r, InterruptionCause.locationServicesOff, before.now);
      // The tracker keeps ticking while the services are off.
      for (int t = 5; t <= 60; t += 5) {
        r.ticked('j1', before.now.add(_s * t));
      }
      final GpsScript after = GpsScript(start: before.now.add(_min))
        ..lat = before.lat
        ..lng = before.lng
        ..speed = GpsScript.ms(60)
        ..drive(60, _s * 30);
      after.play(r, start: false);
      expect(r.interruptions, hasLength(1));
      expect(r.cleared.single.resolution, IncidentResolution.trackingRestored);
      expect(r.movement, isEmpty);
    });

    test('19. suspended in the background mid-drop: low, the drop dropped', () {
      final EngineRecorder r = replay(
        GpsScript()
          ..drive(60, _min)
          ..drop(0)
          ..hold(_s * 6)
          ..pause(_s * 45)
          ..hold(_s * 40),
      );
      expect(r.movement, isEmpty);
      expect(
        r.interruptions.single.interruption,
        InterruptionCause.appSuspended,
      );
    });
  });

  group('lifecycle, with the monitor and the safety check', () {
    late MemoryIncidentRepository store;
    late MemorySafetyCheckRepository checks;
    late FirestoreJourneyRepository journeys;
    late DateTime clock;
    final List<SafetyCheckService> services = <SafetyCheckService>[];

    setUp(() {
      store = MemoryIncidentRepository();
      checks = MemorySafetyCheckRepository();
      journeys = FirestoreJourneyRepository(
        FakeFirebaseFirestore(),
        _Session(),
      );
      clock = DateTime.utc(2026, 11, 8, 9);
    });

    tearDown(() async {
      for (final SafetyCheckService s in services) {
        await s.dispose();
      }
      services.clear();
    });

    Future<String> activeJourney() async {
      final JourneyModel j = await journeys.plan(
        origin: 'Home',
        destination: 'Work',
        departsAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await journeys.start(
        j.id,
        checklistVersion: 1,
        confirmed: JourneyChecklist.itemsOf(1).toSet(),
      );
      return j.id;
    }

    SafetyCheckService service() {
      final SafetyCheckService s = SafetyCheckService(
        incidents: store,
        checks: checks,
        journeys: journeys,
        session: _Session(),
        notifications: FakeSafetyNotifications(),
        inForeground: () => true,
        clock: () => clock,
        timer: FakeTimers(() => clock).call,
      );
      services.add(s);
      return s;
    }

    /// Plays [s] into [m] for [journeyId], with the safety check's clock on
    /// the script's, and lets everything settle.
    Future<void> play(
      IncidentMonitor m,
      GpsScript s,
      String journeyId, {
      bool start = true,
      DateTime? lastFixBefore,
    }) async {
      if (start && lastFixBefore != null) {
        m.started('sara', journeyId, s.start, lastFixBefore: lastFixBefore);
      }
      s.play(m, journeyId: journeyId, start: start && lastFixBefore == null);
      clock = s.now;
      await m.idle;
      await pumpEventQueue();
    }

    Future<List<PotentialIncident>> movement(String journeyId) async =>
        <PotentialIncident>[
          for (final PotentialIncident i in await store.forJourney(
            'sara',
            journeyId,
          ))
            if (i.type != IncidentType.trackingInterrupted) i,
        ];

    test('20. after the app was killed and reopened in the same place, the '
        'same stop is not asked about again', () async {
      final String j = await activeJourney();
      final SafetyCheckService first = service();
      final GpsScript s = GpsScript()
        ..drive(50, _min * 3)
        ..brake(0, 3)
        ..hold(_min * 6);
      await play(IncidentMonitor(store), s, j);
      await first.idle;
      expect(await movement(j), hasLength(1));
      expect(
        (await checks.forUser('sara')).single.status,
        SafetyCheckStatus.pending,
      );

      // Killed; reopened ten minutes later, still parked there.
      final DateTime lastFix = s.now;
      final GpsScript reopened = GpsScript(start: s.now.add(_min * 10))
        ..lat = s.lat
        ..lng = s.lng
        ..hold(_min * 7);
      final IncidentMonitor second = IncidentMonitor(store);
      await play(second, reopened, j, lastFixBefore: lastFix);
      final SafetyCheckService again = service();
      await again.recover();
      expect(await movement(j), hasLength(1), reason: 'the same stop');
      expect(
        await checks.forUser('sara'),
        hasLength(1),
        reason: 'one question',
      );

      // It drives off and stops somewhere else: that is new.
      final GpsScript onwards = GpsScript(start: reopened.now)
        ..lat = reopened.lat
        ..lng = reopened.lng
        ..accelerate(50, 2.5)
        ..drive(50, _min * 2)
        ..brake(0, 3)
        ..hold(_min * 6);
      await play(second, onwards, j, start: false);
      final List<PotentialIncident> all = await movement(j)
        ..sort(
          (PotentialIncident a, PotentialIncident b) =>
              a.detectedAt.compareTo(b.detectedAt),
        );
      expect(all, hasLength(2));
      // The new stop gets its own question; the first one's had timed out.
      expect(all.last.status, IncidentStatus.awaitingConfirmation);
      expect(await checks.forUser('sara'), hasLength(2));
    });

    test('21. "I\'m safe" is final for that stop; a new stop is new', () async {
      final String j = await activeJourney();
      final SafetyCheckService checker = service();
      final IncidentMonitor m = IncidentMonitor(store);
      final GpsScript s = GpsScript()
        ..drive(50, _min * 3)
        ..brake(0, 3)
        ..hold(_min * 6);
      await play(m, s, j);
      await checker.idle;
      final SafetyCheck asked = (await checks.forUser('sara')).single;
      expect(await checker.confirm(asked.id), ConfirmOutcome.confirmed);
      expect((await movement(j)).single.status, IncidentStatus.dismissed);

      final GpsScript stillThere = GpsScript(start: s.now)
        ..lat = s.lat
        ..lng = s.lng
        ..hold(_min * 15);
      await play(m, stillThere, j, start: false);
      await checker.idle;
      expect(await movement(j), hasLength(1));
      expect(await checks.forUser('sara'), hasLength(1));
    });

    test('21b. "I\'m safe" after a sudden stop also covers the long stop '
        'that follows it there', () async {
      final String j = await activeJourney();
      final SafetyCheckService checker = service();
      final IncidentMonitor m = IncidentMonitor(store);
      final GpsScript s = GpsScript()
        ..drive(60, _min)
        ..drop(0)
        ..hold(_s * 20);
      await play(m, s, j);
      await checker.idle;
      final SafetyCheck asked = (await checks.forUser('sara')).single;
      expect(await checker.confirm(asked.id), ConfirmOutcome.confirmed);

      final GpsScript parked = GpsScript(start: s.now)
        ..lat = s.lat
        ..lng = s.lng
        ..hold(_min * 7);
      await play(m, parked, j, start: false);
      await checker.idle;
      expect(await movement(j), hasLength(1), reason: 'no second event');
      expect(await checks.forUser('sara'), hasLength(1));

      // Driven on and stopped again elsewhere: that is asked about.
      final GpsScript later = GpsScript(start: parked.now)
        ..lat = parked.lat
        ..lng = parked.lng
        ..accelerate(50, 2.5)
        ..drive(50, _min * 2)
        ..brake(0, 3)
        ..hold(_min * 6);
      await play(m, later, j, start: false);
      await checker.idle;
      expect(await movement(j), hasLength(2));
    });

    test('22. moving on resolves an open stop', () async {
      final String j = await activeJourney();
      final IncidentMonitor m = IncidentMonitor(store);
      await play(
        m,
        GpsScript()
          ..drive(50, _min * 3)
          ..brake(0, 3)
          ..hold(_min * 6)
          ..accelerate(40, 2)
          ..drive(40, _s * 30),
        j,
      );
      final PotentialIncident stop = (await movement(j)).single;
      expect(stop.status, IncidentStatus.resolved);
      expect(stop.resolution, IncidentResolution.movementResumed);
    });

    test('23. a new journey after an earlier incident starts clean', () async {
      final String first = await activeJourney();
      final IncidentMonitor m = IncidentMonitor(store);
      final GpsScript s = GpsScript()
        ..drive(50, _min * 3)
        ..brake(0, 3)
        ..hold(_min * 6);
      await play(m, s, first);
      m.ended('sara', first, s.now);
      await m.idle;
      expect(
        (await movement(first)).single.resolution,
        IncidentResolution.journeyEnded,
      );

      final String second = await activeJourney();
      final GpsScript next = GpsScript(start: s.now.add(_min))
        ..lat = s.lat
        ..lng = s.lng
        ..drive(50, _min * 3)
        ..brake(0, 3)
        ..hold(_min * 6);
      await play(m, next, second);
      expect((await movement(second)).single.status, IncidentStatus.detected);
    });

    test('an interruption or a low event never asks "Are you okay?"', () async {
      final String j = await activeJourney();
      final SafetyCheckService checker = service();
      final IncidentMonitor m = IncidentMonitor(store);
      final GpsScript s = GpsScript()..drive(60, _min);
      await play(m, s, j);
      m.interrupted(j, InterruptionCause.permissionRemoved, s.now);
      final GpsScript poor = GpsScript(start: s.now.add(_min))
        ..lat = s.lat
        ..lng = s.lng;
      poor.reporting(
        accuracy: 18,
        steps: (GpsScript g) => g
          ..speed = GpsScript.ms(60)
          ..drive(60, _min)
          ..drop(0)
          ..hold(_min * 6),
      );
      await play(m, poor, j, start: false);
      await checker.idle;
      final List<PotentialIncident> all = await store.forJourney('sara', j);
      expect(
        all.any(
          (PotentialIncident i) => i.type == IncidentType.trackingInterrupted,
        ),
        isTrue,
      );
      expect(
        all.every(
          (PotentialIncident i) => i.confidence == IncidentConfidence.low,
        ),
        isTrue,
      );
      expect(await checks.forUser('sara'), isEmpty);
    });
  });
}
