import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_detection_engine.dart';

/// Drives a simulated journey north from Riyadh, one fix at a time, and
/// collects what the engine concludes.
class _Drive {
  _Drive() {
    engine.started(now);
  }

  final IncidentDetectionEngine engine = IncidentDetectionEngine(
    journeyId: 'j1',
  );
  final List<DetectorOutput> outputs = <DetectorOutput>[];
  DateTime now = DateTime.utc(2026, 11, 3, 9);
  double metres = 0;

  /// [seconds] later, moved [moved] metres (default: speed × time).
  void fix(
    double speed, {
    double seconds = 2,
    double? moved,
    double accuracy = 5,
    double? speedError = 0.5,
    bool hasSpeed = true,
    Duration lag = Duration.zero,
  }) {
    now = now.add(Duration(milliseconds: (seconds * 1000).round()));
    metres += moved ?? speed * seconds;
    outputs.addAll(
      engine.fix(
        LocationFix(
          latitude: 24.7 + metres / 111195,
          longitude: 46.67,
          at: now.subtract(lag),
          accuracy: accuracy,
          speed: hasSpeed ? speed : null,
          speedAccuracy: hasSpeed ? speedError : null,
        ),
        now,
      ),
    );
  }

  /// Steady driving at [speed] for [seconds].
  void cruise(double speed, double seconds, {double accuracy = 5}) {
    for (double t = 0; t < seconds; t += 2) {
      fix(speed, accuracy: accuracy);
    }
  }

  /// Ordinary braking from [speed] to a stop, about 2.5 m/s².
  void brake(double speed) {
    for (double v = speed - 5; v > 0.5; v -= 5) {
      fix(v);
    }
    fix(0.3);
  }

  /// Standing still for [seconds], a fix every 2 s.
  void still(double seconds, {double accuracy = 5, bool hasSpeed = true}) {
    for (double t = 0; t < seconds; t += 2) {
      fix(0.2, moved: 0, accuracy: accuracy, hasSpeed: hasSpeed);
    }
  }

  void tick([Duration after = const Duration(seconds: 5)]) {
    now = now.add(after);
    outputs.addAll(engine.tick(now));
  }

  List<IncidentSignal> detected([IncidentType? type]) => <IncidentSignal>[
    for (final DetectorOutput o in outputs)
      if (o case IncidentDetected(:final IncidentSignal signal))
        if (type == null || signal.type == type) signal,
  ];

  List<IncidentCleared> cleared() =>
      outputs.whereType<IncidentCleared>().toList();
}

void main() {
  group('sudden deceleration', () {
    test('a hard stop from driving speed that lasts: high confidence', () {
      final _Drive d = _Drive()..cruise(15, 12);
      // 15 → 0.5 m/s in 2 s: 7.25 m/s², positions consistent.
      d.fix(0.5, moved: 15.5);
      expect(d.detected(), isEmpty, reason: 'not before it lasts');
      d.still(16);
      final List<IncidentSignal> s = d.detected(
        IncidentType.suddenDeceleration,
      );
      expect(s, hasLength(1));
      expect(s.single.confidence, IncidentConfidence.high);
      expect(s.single.speedBefore, 15);
      expect(s.single.deceleration, closeTo(7.25, 0.01));
      expect(s.single.lat, isNotNull);
      expect(s.single.accuracy, 5);
    });

    test('a fair fix and no speed error from the phone: medium at most', () {
      final _Drive d = _Drive();
      for (int i = 0; i < 6; i++) {
        d.fix(12.5, accuracy: 12, speedError: null);
      }
      d
        ..fix(0.5, moved: 13, accuracy: 12, speedError: null)
        ..still(16, accuracy: 12);
      expect(
        d.detected(IncidentType.suddenDeceleration).single.confidence,
        IncidentConfidence.medium,
      );
    });

    test('driving speed seen only once before the drop: low', () {
      final _Drive d = _Drive()
        ..fix(4)
        ..fix(15, moved: 19)
        ..fix(0.5, moved: 15.5)
        ..still(16);
      expect(
        d.detected(IncidentType.suddenDeceleration).single.confidence,
        IncidentConfidence.low,
      );
    });

    test('gradual braking to a stop is not reported', () {
      final _Drive d = _Drive()..cruise(14, 12);
      for (final double v in <double>[11, 8, 5, 2, 0.3]) {
        d.fix(v);
      }
      d.still(30);
      expect(d.detected(), isEmpty);
    });

    test('an ordinary red light (firm braking, a minute, drive on)', () {
      final _Drive d = _Drive()..cruise(13.9, 12);
      for (final double v in <double>[9, 4, 0.4]) {
        d.fix(v);
      }
      d
        ..still(60)
        ..cruise(10, 20);
      expect(d.detected(), isEmpty);
    });

    test('a hard brake that drives on is not reported', () {
      final _Drive d = _Drive()
        ..cruise(15, 12)
        ..fix(0.5, moved: 15.5)
        ..fix(0.5, moved: 0)
        ..cruise(6, 10)
        ..still(30);
      expect(d.detected(), isEmpty);
    });

    test('a speed that the positions contradict is a glitch', () {
      final _Drive d = _Drive()
        ..cruise(15, 12)
        // "0.5 m/s", yet it moved 60 m in 2 s.
        ..fix(0.5, moved: 60)
        ..still(20);
      expect(d.detected(IncidentType.suddenDeceleration), isEmpty);
    });

    test('poor accuracy is never trusted', () {
      final _Drive d = _Drive()
        ..cruise(15, 12, accuracy: 40)
        ..fix(0.5, moved: 15.5, accuracy: 40)
        ..still(30, accuracy: 40);
      expect(d.detected(), isEmpty);
    });

    test('stale fixes are ignored', () {
      final _Drive d = _Drive()..cruise(15, 12);
      d.fix(0.5, moved: 15.5, lag: const Duration(seconds: 20));
      d.still(20);
      expect(d.detected(IncidentType.suddenDeceleration), isEmpty);
    });

    test('without speed readings there is no deceleration', () {
      final _Drive d = _Drive();
      for (int i = 0; i < 6; i++) {
        d.fix(15, hasSpeed: false);
      }
      d
        ..fix(0.5, moved: 15.5, hasSpeed: false)
        ..still(20, hasSpeed: false);
      expect(d.detected(), isEmpty);
    });

    test('an unreliable speed error is ignored', () {
      final _Drive d = _Drive();
      for (int i = 0; i < 6; i++) {
        d.fix(15, speedError: 4);
      }
      d
        ..fix(0.5, moved: 15.5, speedError: 4)
        ..still(20);
      expect(d.detected(IncidentType.suddenDeceleration), isEmpty);
    });

    test('reported once; cleared when movement resumes', () {
      final _Drive d = _Drive()
        ..cruise(15, 12)
        ..fix(0.5, moved: 15.5)
        ..still(60);
      expect(d.detected(), hasLength(1));
      d.cruise(6, 6);
      expect(
        d.cleared().map((IncidentCleared c) => c.type),
        contains(IncidentType.suddenDeceleration),
      );
      expect(d.cleared().first.resolution, IncidentResolution.movementResumed);
    });

    test('a drop followed only by silence is dropped, not confirmed', () {
      final _Drive d = _Drive()
        ..cruise(15, 12)
        ..fix(0.5, moved: 15.5)
        ..tick(const Duration(seconds: 35))
        ..still(30);
      expect(d.detected(IncidentType.suddenDeceleration), isEmpty);
    });
  });

  group('prolonged stop', () {
    test('five minutes still after moving: medium, once', () {
      final _Drive d = _Drive()
        ..cruise(12, 40)
        ..brake(12)
        ..still(310);
      final List<IncidentSignal> s = d.detected(IncidentType.prolongedStop);
      expect(s, hasLength(1));
      expect(s.single.confidence, IncidentConfidence.medium);
      expect(s.single.duration! >= const Duration(minutes: 5), isTrue);
      d.still(120);
      expect(d.detected(IncidentType.prolongedStop), hasLength(1));
    });

    test('short stops never reach it', () {
      final _Drive d = _Drive()..cruise(12, 40);
      for (int i = 0; i < 4; i++) {
        d
          ..brake(12)
          ..still(90)
          ..cruise(12, 20);
      }
      expect(d.detected(), isEmpty);
    });

    test('waiting before the journey moves is not unusual', () {
      final _Drive d = _Drive()..still(600);
      expect(d.detected(), isEmpty);
    });

    test('a gap in the data restarts the count', () {
      final _Drive d = _Drive()
        ..cruise(12, 40)
        ..brake(12)
        ..still(200)
        ..fix(0.2, seconds: 90, moved: 0)
        ..still(200);
      expect(d.detected(IncidentType.prolongedStop), isEmpty);
    });

    test('moving again clears it', () {
      final _Drive d = _Drive()
        ..cruise(12, 40)
        ..brake(12)
        ..still(310)
        ..cruise(10, 10);
      expect(
        d.cleared().map((IncidentCleared c) => c.type),
        contains(IncidentType.prolongedStop),
      );
    });

    test('a long stop right after a sudden deceleration: high', () {
      final _Drive d = _Drive()
        ..cruise(15, 12)
        ..fix(0.5, moved: 15.5)
        ..still(310);
      expect(
        d.detected(IncidentType.prolongedStop).single.confidence,
        IncidentConfidence.high,
      );
    });

    test('a stop seen through poor accuracy is low', () {
      final _Drive d = _Drive()
        ..cruise(12, 40)
        ..brake(12)
        ..still(310, accuracy: 22);
      expect(
        d.detected(IncidentType.prolongedStop).single.confidence,
        IncidentConfidence.low,
      );
    });
  });

  group('tracking interrupted', () {
    test('no fix for a minute: signal lost, low, never a movement event', () {
      final _Drive d = _Drive()..cruise(15, 12);
      for (int i = 0; i < 13; i++) {
        d.tick(); // every 5 s, as the tracker ticks
      }
      final IncidentSignal s = d.detected().single;
      expect(s.type, IncidentType.trackingInterrupted);
      expect(s.interruption, InterruptionCause.signalLost);
      expect(s.confidence, IncidentConfidence.low);
      d.tick();
      expect(d.detected(), hasLength(1));
      d.fix(14, seconds: 1, moved: 900);
      expect(
        d.cleared().single.resolution,
        IncidentResolution.trackingRestored,
      );
    });

    test('permission removed or services off: the cause, once', () {
      final _Drive d = _Drive()..cruise(15, 6);
      d.outputs.addAll(
        d.engine.interrupted(InterruptionCause.permissionRemoved, d.now),
      );
      d.outputs.addAll(
        d.engine.interrupted(InterruptionCause.permissionRemoved, d.now),
      );
      expect(
        d.detected().single.interruption,
        InterruptionCause.permissionRemoved,
      );
      d.outputs.addAll(
        d.engine.interrupted(InterruptionCause.locationServicesOff, d.now),
      );
      expect(
        d.detected().last.interruption,
        InterruptionCause.locationServicesOff,
      );
      d.tick(const Duration(minutes: 3));
      expect(d.detected(), hasLength(2), reason: 'no signal-lost on top');
    });

    test('the app suspended: its timers skipped a beat', () {
      final _Drive d = _Drive()
        ..cruise(15, 6)
        ..tick(const Duration(seconds: 45));
      expect(d.detected().single.interruption, InterruptionCause.appSuspended);
    });

    test('resumed after the app was closed', () {
      final IncidentDetectionEngine e = IncidentDetectionEngine(
        journeyId: 'j1',
      );
      final DateTime now = DateTime.utc(2026, 11, 3, 9);
      final List<DetectorOutput> out = e.started(
        now,
        lastFixBefore: now.subtract(const Duration(minutes: 4)),
      );
      final IncidentSignal s = (out.single as IncidentDetected).signal;
      expect(s.interruption, InterruptionCause.appClosed);
      expect(s.duration, const Duration(minutes: 4));
      expect(
        e.started(now, lastFixBefore: now.subtract(const Duration(seconds: 5))),
        isEmpty,
      );
    });

    test('a stop is not counted through an interruption', () {
      final _Drive d = _Drive()
        ..cruise(12, 40)
        ..brake(12)
        ..still(200);
      d.outputs.addAll(
        d.engine.interrupted(InterruptionCause.signalLost, d.now),
      );
      d.still(200);
      expect(d.detected(IncidentType.prolongedStop), isEmpty);
    });
  });
}
