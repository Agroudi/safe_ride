import 'dart:math' as math;

import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_detection_engine.dart';
import 'package:safe_ride/features/journeys/data/repository/tracking_observer.dart';

/// Something that happens to the phone in a script.
sealed class ScriptEvent {
  const ScriptEvent();
}

/// A fix, and when it reached the app (later than it was taken, when stale).
final class ScriptedFix extends ScriptEvent {
  const ScriptedFix(this.fix, this.arrives);

  final LocationFix fix;
  final DateTime arrives;
}

/// The app was suspended or closed until [until]: no fixes, no ticks.
final class ScriptedPause extends ScriptEvent {
  const ScriptedPause(this.until);

  final DateTime until;
}

/// A synthetic journey, one fix every [every] as the tracker asks for, built
/// step by step so each scenario reads as what happens on the road. The same
/// script always gives the same fixes: positions follow [heading] from Riyadh;
/// a stationary phone's fixes wander a deterministic couple of metres, as real
/// ones do.
class GpsScript {
  GpsScript({DateTime? start, this.every = const Duration(seconds: 2)})
    : start = start ?? DateTime.utc(2026, 11, 8, 9),
      now = start ?? DateTime.utc(2026, 11, 8, 9);

  final DateTime start;
  final Duration every;
  final List<ScriptEvent> events = <ScriptEvent>[];

  DateTime now;
  double lat = 24.7;
  double lng = 46.67;

  /// Degrees clockwise from north.
  double heading = 0;
  double speed = 0;

  /// What the phone reports with each fix (change for a stretch of road).
  double accuracy = 5;
  double? speedError = 0.5;
  bool reportsSpeed = true;

  int _wobble = 0;

  double get _seconds => every.inMilliseconds / 1000;

  /// Moves [metres] along [heading].
  void _advance(double metres) {
    final double h = heading * math.pi / 180;
    lat += metres * math.cos(h) / 111195;
    lng += metres * math.sin(h) / (111195 * math.cos(lat * math.pi / 180));
  }

  void _emit({
    double? atLat,
    double? atLng,
    Duration lag = Duration.zero,
    DateTime? takenAt,
  }) {
    final DateTime taken = takenAt ?? now;
    events.add(
      ScriptedFix(
        LocationFix(
          latitude: atLat ?? lat,
          longitude: atLng ?? lng,
          at: taken,
          accuracy: accuracy,
          speed: reportsSpeed ? speed : null,
          speedAccuracy: reportsSpeed ? speedError : null,
        ),
        taken.add(lag),
      ),
    );
  }

  /// One step at [kmh] reached by the end of it, the distance from the
  /// average of the two speeds.
  void _step(double nextSpeed) {
    now = now.add(every);
    _advance((speed + nextSpeed) / 2 * _seconds);
    speed = nextSpeed;
    _emit();
  }

  static double ms(double kmh) => kmh / 3.6;

  /// Steady driving at [kmh] for [d].
  GpsScript drive(double kmh, Duration d) {
    for (int i = 0; i < d.inMilliseconds ~/ every.inMilliseconds; i++) {
      _step(ms(kmh));
    }
    return this;
  }

  /// Slowing from the current speed to [kmh] at [mps2].
  GpsScript brake(double kmh, double mps2) {
    final double target = ms(kmh);
    while (speed > target + 1e-9) {
      _step(math.max(target, speed - mps2 * _seconds));
    }
    return this;
  }

  /// Speeding up to [kmh] at [mps2].
  GpsScript accelerate(double kmh, double mps2) {
    final double target = ms(kmh);
    while (speed < target - 1e-9) {
      _step(math.min(target, speed + mps2 * _seconds));
    }
    return this;
  }

  /// From driving to [kmh] within one fix, as GPS sees an impact (or the
  /// hardest stop).
  GpsScript drop(double kmh) {
    _step(ms(kmh));
    return this;
  }

  /// Standing still for [d]: speed near zero, positions wandering a couple
  /// of metres.
  GpsScript hold(Duration d, {double kmh = 0.5}) {
    final double centreLat = lat;
    final double centreLng = lng;
    speed = ms(kmh);
    for (int i = 0; i < d.inMilliseconds ~/ every.inMilliseconds; i++) {
      now = now.add(every);
      final double off = (_wobble++ % 3 - 1) * 2 / 111195;
      _emit(atLat: centreLat + off, atLng: centreLng - off);
    }
    return this;
  }

  /// Inching forward at [kmh] for [d] (a queue).
  GpsScript crawl(double kmh, Duration d) {
    speed = ms(kmh);
    for (int i = 0; i < d.inMilliseconds ~/ every.inMilliseconds; i++) {
      now = now.add(every);
      _advance(speed * _seconds);
      _emit();
    }
    return this;
  }

  GpsScript turn(double degrees) {
    heading = (heading + degrees) % 360;
    return this;
  }

  /// No fixes for [d] while the app keeps running (a tunnel, a lost signal).
  GpsScript gap(Duration d) {
    now = now.add(d);
    _advance(speed * d.inMilliseconds / 1000);
    return this;
  }

  /// The app suspended or killed for [d]: no fixes and no ticks.
  GpsScript pause(Duration d) {
    now = now.add(d);
    events.add(ScriptedPause(now));
    return this;
  }

  /// One fix [metres] away from the truth (east), then the truth again.
  GpsScript jump(double metres) {
    now = now.add(every);
    _advance(speed * _seconds);
    _emit(atLng: lng + metres / (111195 * math.cos(lat * math.pi / 180)));
    return this;
  }

  /// The last fix again, same timestamp.
  GpsScript repeat() {
    final ScriptedFix last = events.whereType<ScriptedFix>().last;
    events.add(
      ScriptedFix(
        last.fix,
        last.arrives.add(const Duration(milliseconds: 200)),
      ),
    );
    return this;
  }

  /// A fix taken [back] before the latest one, arriving now.
  GpsScript late(Duration back) {
    final ScriptedFix last = events.whereType<ScriptedFix>().last;
    events.add(
      ScriptedFix(
        LocationFix(
          latitude: last.fix.latitude - 30 / 111195,
          longitude: last.fix.longitude,
          at: last.fix.at.subtract(back),
          accuracy: last.fix.accuracy,
          speed: last.fix.speed,
          speedAccuracy: last.fix.speedAccuracy,
        ),
        last.arrives.add(const Duration(milliseconds: 300)),
      ),
    );
    return this;
  }

  /// One fix that is already [lag] old when it arrives (a cached position).
  GpsScript stale(Duration lag) {
    now = now.add(every);
    _advance(speed * _seconds);
    _emit(lag: lag, takenAt: now.subtract(lag));
    return this;
  }

  /// Changes what the phone reports for the steps that [steps] adds.
  GpsScript reporting({
    double? accuracy,
    double? speedError,
    bool unknownSpeedError = false,
    bool? speed,
    required void Function(GpsScript) steps,
  }) {
    final double a = this.accuracy;
    final double? e = this.speedError;
    final bool s = reportsSpeed;
    this.accuracy = accuracy ?? a;
    this.speedError = unknownSpeedError ? null : speedError ?? e;
    reportsSpeed = speed ?? s;
    steps(this);
    this.accuracy = a;
    this.speedError = e;
    reportsSpeed = s;
    return this;
  }

  /// Plays the script into [observer] as `JourneyTracker` would: every fix
  /// as it arrives, and a tick every [tickEvery] while the app runs.
  void play(
    TrackingObserver observer, {
    String uid = 'sara',
    String journeyId = 'j1',
    Duration tickEvery = const Duration(seconds: 5),
    bool start = true,
    IncidentPlace? destination,
  }) {
    if (start) {
      observer.started(uid, journeyId, this.start, destination: destination);
    }
    DateTime nextTick = this.start.add(tickEvery);
    void ticksUntil(DateTime t) {
      while (!nextTick.isAfter(t)) {
        observer.ticked(journeyId, nextTick);
        nextTick = nextTick.add(tickEvery);
      }
    }

    final List<ScriptEvent> ordered = List<ScriptEvent>.of(events);
    for (final ScriptEvent e in ordered) {
      switch (e) {
        case ScriptedFix(:final LocationFix fix, :final DateTime arrives):
          ticksUntil(arrives);
          observer.fixed(journeyId, fix, arrives);
        case ScriptedPause(:final DateTime until):
          // Suspended: the tracker's timer did not run until now.
          nextTick = until;
      }
    }
    ticksUntil(now);
  }
}

/// Collects what one engine concludes from a script, as the monitor would
/// receive it.
class EngineRecorder implements TrackingObserver {
  EngineRecorder({IncidentDetectionEngine? engine, this.destination})
    : engine = engine ?? IncidentDetectionEngine(journeyId: 'j1');

  IncidentDetectionEngine engine;
  final IncidentPlace? destination;
  final List<DetectorOutput> outputs = <DetectorOutput>[];

  @override
  void started(
    String uid,
    String journeyId,
    DateTime at, {
    DateTime? lastFixBefore,
    IncidentPlace? destination,
  }) {
    final IncidentPlace? place = destination ?? this.destination;
    if (place != null && engine.destination == null) {
      engine = IncidentDetectionEngine(
        journeyId: journeyId,
        destination: place,
      );
    }
    outputs.addAll(engine.started(at, lastFixBefore: lastFixBefore));
  }

  @override
  void fixed(String journeyId, LocationFix fix, DateTime at) =>
      outputs.addAll(engine.fix(fix, at));

  @override
  void ticked(String journeyId, DateTime at) => outputs.addAll(engine.tick(at));

  @override
  void interrupted(String journeyId, InterruptionCause cause, DateTime at) =>
      outputs.addAll(engine.interrupted(cause, at));

  @override
  void paused(String journeyId) {}

  @override
  void ended(String uid, String journeyId, DateTime at) {}

  List<IncidentSignal> get signals => <IncidentSignal>[
    for (final DetectorOutput o in outputs)
      if (o case IncidentDetected(:final IncidentSignal signal)) signal,
  ];

  /// Movement events (never interruptions), any confidence.
  List<IncidentSignal> get movement => <IncidentSignal>[
    for (final IncidentSignal s in signals)
      if (s.type != IncidentType.trackingInterrupted) s,
  ];

  /// What would ask "Are you okay?": a movement event of medium or high
  /// confidence (`SafetyCheckEligibility`).
  List<IncidentSignal> get asks => <IncidentSignal>[
    for (final IncidentSignal s in movement)
      if (s.confidence != IncidentConfidence.low) s,
  ];

  List<IncidentSignal> get interruptions => <IncidentSignal>[
    for (final IncidentSignal s in signals)
      if (s.type == IncidentType.trackingInterrupted) s,
  ];

  List<IncidentCleared> get cleared =>
      outputs.whereType<IncidentCleared>().toList();
}
