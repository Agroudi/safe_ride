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

const Duration _s = Duration(seconds: 1);
const Duration _min = Duration(minutes: 1);

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

/// A drive at [kmh], a drop to nothing between two fixes, and a hold. Returns
/// the script and when the drop was recorded.
(GpsScript, DateTime) hardStop(
  double kmh, {
  bool speedError = true,
  Duration hold = const Duration(seconds: 60),
}) {
  final GpsScript s = GpsScript();
  s.reporting(
    unknownSpeedError: !speedError,
    steps: (GpsScript g) => g
      ..drive(kmh, _min)
      ..drop(0),
  );
  final DateTime dropAt = s.now;
  s.reporting(
    unknownSpeedError: !speedError,
    steps: (GpsScript g) => g.hold(hold),
  );
  return (s, dropAt);
}

IncidentSignal onlyDeceleration(EngineRecorder r) => r.movement.singleWhere(
  (IncidentSignal x) => x.type == IncidentType.suddenDeceleration,
);

/// When detection decides, how sure it is, and when the 15-second check
/// begins. Replays with fixed timestamps, so every second is exact.
void main() {
  group('when a hard stop is reported', () {
    test('the emulator run, replayed: 50 km/h to 0 is 6.94 m/s², below the '
        '7.0 that high needs — medium, at the first fix past 45 s', () {
      for (final bool speedError in <bool>[true, false]) {
        final (GpsScript s, DateTime dropAt) = hardStop(
          50,
          speedError: speedError,
        );
        final EngineRecorder r = EngineRecorder();
        s.play(r);
        final IncidentSignal d = onlyDeceleration(r);
        expect(d.deceleration, closeTo(6.94, 0.01));
        expect(d.confidence, IncidentConfidence.medium);
        expect(d.at.difference(dropAt), const Duration(seconds: 46));
      }
    });

    test('a high-confidence stop is reported at the first fix past 15 s', () {
      final (GpsScript s, DateTime dropAt) = hardStop(60);
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      final IncidentSignal d = onlyDeceleration(r);
      expect(d.deceleration, closeTo(8.33, 0.01));
      expect(d.confidence, IncidentConfidence.high);
      expect(d.at.difference(dropAt), const Duration(seconds: 16));
    });

    test('nothing is reported before 15 s, whatever the evidence', () {
      final (GpsScript s, _) = hardStop(60, hold: const Duration(seconds: 14));
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      expect(r.movement, isEmpty);
    });

    test('the same strong drop without a reported speed error waits for '
        '45 s, as medium', () {
      final (GpsScript s, DateTime dropAt) = hardStop(60, speedError: false);
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      final IncidentSignal d = onlyDeceleration(r);
      expect(d.confidence, IncidentConfidence.medium);
      expect(d.at.difference(dropAt), const Duration(seconds: 46));
    });

    test('with a fix every 2 s the five-fix rule is met long before 15 s', () {
      final (GpsScript s, DateTime dropAt) = hardStop(60);
      final int fixesBy15 = s.events
          .whereType<ScriptedFix>()
          .where(
            (ScriptedFix f) =>
                f.fix.at.isAfter(dropAt) &&
                !f.fix.at.isAfter(dropAt.add(const Duration(seconds: 15))),
          )
          .length;
      expect(fixesBy15, 7);
    });

    /// Strong data, but a still fix only every [every] after the drop.
    (GpsScript, DateTime) sparse(Duration every) {
      final GpsScript s = GpsScript()
        ..drive(60, _min)
        ..drop(0);
      final DateTime dropAt = s.now;
      for (int i = 0; i < 10; i++) {
        s
          ..gap(every - const Duration(seconds: 2))
          ..hold(const Duration(seconds: 2));
      }
      return (s, dropAt);
    }

    test('fixes every 6 s give 3 by 15 s: not high then; high only once the '
        'fifth arrives, at 30 s', () {
      final (GpsScript s, DateTime dropAt) = sparse(const Duration(seconds: 6));
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      final IncidentSignal d = onlyDeceleration(r);
      expect(d.confidence, IncidentConfidence.high);
      expect(d.at.difference(dropAt), const Duration(seconds: 30));
    });

    test(
      'fixes every 7 s are never steady enough for high: medium at 45 s',
      () {
        final (GpsScript s, DateTime dropAt) = sparse(
          const Duration(seconds: 7),
        );
        final EngineRecorder r = EngineRecorder();
        s.play(r);
        final IncidentSignal d = onlyDeceleration(r);
        expect(d.confidence, IncidentConfidence.medium);
        expect(d.at.difference(dropAt), const Duration(seconds: 49));
      },
    );

    test('a gap over 6 s while still: not high, even with enough fixes', () {
      final GpsScript s = GpsScript()
        ..drive(60, _min)
        ..drop(0);
      final DateTime dropAt = s.now;
      s
        ..hold(const Duration(seconds: 4))
        ..gap(const Duration(seconds: 6))
        ..hold(const Duration(seconds: 50));
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      final IncidentSignal d = onlyDeceleration(r);
      expect(d.confidence, IncidentConfidence.medium);
      expect(d.at.difference(dropAt), greaterThanOrEqualTo(_s * 45));
    });
  });

  group('the 15-second check begins only once detection has reported', () {
    late MemoryIncidentRepository store;
    late MemorySafetyCheckRepository checks;
    late FirestoreJourneyRepository journeys;
    late DateTime clock;
    late SafetyCheckService service;

    setUp(() async {
      store = MemoryIncidentRepository();
      checks = MemorySafetyCheckRepository();
      journeys = FirestoreJourneyRepository(
        FakeFirebaseFirestore(),
        _Session(),
      );
      clock = DateTime.utc(2026, 11, 8, 9);
      service = SafetyCheckService(
        incidents: store,
        checks: checks,
        journeys: journeys,
        session: _Session(),
        notifications: FakeSafetyNotifications(),
        inForeground: () => true,
        clock: () => clock,
        timer: FakeTimers(() => clock).call,
      );
    });

    tearDown(() => service.dispose());

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

    /// Feeds [s] one fix at a time, the service's clock on each fix, and
    /// records whether a check existed before the incident did.
    Future<(SafetyCheck, PotentialIncident)> feed(
      GpsScript s,
      String journeyId,
    ) async {
      final IncidentMonitor m = IncidentMonitor(store)
        ..started('sara', journeyId, s.start);
      for (final ScriptEvent e in s.events) {
        if (e case ScriptedFix(:final fix, :final arrives)) {
          clock = arrives;
          m.fixed(journeyId, fix, arrives);
          await m.idle;
          await pumpEventQueue();
          await service.idle;
          final List<SafetyCheck> asked = await checks.forUser('sara');
          final List<PotentialIncident> seen = await store.forJourney(
            'sara',
            journeyId,
          );
          if (seen.isEmpty) {
            expect(asked, isEmpty, reason: 'no check before an incident');
          }
          if (asked.isNotEmpty) return (asked.single, seen.single);
        }
      }
      fail('no check was asked');
    }

    for (final (String label, double kmh, Duration after)
        in <(String, double, Duration)>[
          ('high, at 16 s', 60, Duration(seconds: 16)),
          ('medium, at 46 s', 50, Duration(seconds: 46)),
        ]) {
      test(label, () async {
        final String j = await activeJourney();
        final (GpsScript s, DateTime dropAt) = hardStop(kmh);
        final (SafetyCheck check, PotentialIncident incident) = await feed(
          s,
          j,
        );
        expect(incident.detectedAt.difference(dropAt), after);
        expect(check.startedAt, incident.detectedAt);
        expect(check.deadline, check.startedAt.add(_s * 15));
        expect(check.status, SafetyCheckStatus.pending);
      });
    }
  });

  group('the false-positive protections still hold', () {
    test(
      'a hard stop at a light that turns green within 45 s asks nothing',
      () {
        final (GpsScript s, _) = hardStop(
          50,
          hold: const Duration(seconds: 40),
        );
        s
          ..accelerate(50, 2.5)
          ..drive(50, _min);
        final EngineRecorder r = EngineRecorder();
        s.play(r);
        expect(r.movement, isEmpty);
      },
    );

    test('a hard stop into a crawling queue asks nothing', () {
      final (GpsScript s, _) = hardStop(60, hold: const Duration(seconds: 6));
      s.crawl(5, const Duration(seconds: 20));
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      expect(r.movement, isEmpty);
    });

    test('ten minutes of stop-and-go asks nothing', () {
      final GpsScript s = GpsScript()..drive(60, _min);
      for (int i = 0; i < 5; i++) {
        s
          ..accelerate(30, 2.5)
          ..drive(30, const Duration(seconds: 10))
          ..brake(0, 3)
          ..hold(const Duration(seconds: 20))
          ..crawl(5, const Duration(seconds: 10))
          ..hold(const Duration(seconds: 20));
      }
      final EngineRecorder r = EngineRecorder();
      s.play(r);
      expect(r.asks, isEmpty);
    });
  });
}
