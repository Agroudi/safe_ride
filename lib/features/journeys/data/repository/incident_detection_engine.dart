import 'dart:math' as math;

import 'package:safe_ride/features/journeys/data/models/incident_confidence.dart';
import 'package:safe_ride/features/journeys/data/models/incident_detection_config.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/route_math.dart';

/// Something the engine concluded about one journey.
sealed class DetectorOutput {
  const DetectorOutput();
}

/// A potential incident was noticed.
final class IncidentDetected extends DetectorOutput {
  const IncidentDetected(this.signal);

  final IncidentSignal signal;
}

/// The condition behind an open event of [type] ended.
final class IncidentCleared extends DetectorOutput {
  const IncidentCleared(this.type, this.resolution, this.at);

  final IncidentType type;
  final IncidentResolution resolution;
  final DateTime at;
}

/// What the data showed, before it becomes a stored [PotentialIncident].
final class IncidentSignal {
  const IncidentSignal({
    required this.type,
    required this.confidence,
    required this.at,
    required this.reason,
    this.speedBefore,
    this.speedAfter,
    this.deceleration,
    this.duration,
    this.lat,
    this.lng,
    this.accuracy,
    this.fixAge,
    this.interruption,
  });

  final IncidentType type;
  final IncidentConfidence confidence;
  final DateTime at;
  final String reason;

  /// m/s.
  final double? speedBefore;
  final double? speedAfter;

  /// m/s².
  final double? deceleration;
  final Duration? duration;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final Duration? fixAge;
  final InterruptionCause? interruption;
}

/// Watches one journey's tracking for patterns that **may** mean an incident:
/// a sudden deceleration that lasts, a long stop after moving, and tracking
/// that stops. Pure and synchronous — the clock is passed in — so every
/// scenario is replayed with simulated fixes. It reads the tracker's own
/// fixes (no location subscription of its own) and keeps only a few seconds
/// of them.
///
/// **Conservative by design:** untrusted, stale, out-of-order or missing data
/// never produces an event; one reading never changes the engine's mind
/// ([IncidentDetectionConfig.agreeingFixes] in a row must agree); each
/// condition is reported once until it clears; a tracking interruption is
/// never an incident of movement; confidence comes from
/// [IncidentConfidenceRules] alone.
class IncidentDetectionEngine {
  IncidentDetectionEngine({
    required this.journeyId,
    this.config = const IncidentDetectionConfig(),
    this.destination,
  });

  final String journeyId;
  final IncidentDetectionConfig config;

  /// Where the journey was planned to end, when it was picked on the map.
  final IncidentPlace? destination;

  // Sudden deceleration.
  final List<_Reading> _recent = <_Reading>[];
  _Candidate? _candidate;
  bool _decelerationOpen = false;

  /// When the vehicle stood still after the last sudden deceleration of
  /// medium or high confidence.
  DateTime? _stoppedAfterDeceleration;

  // Setting off.
  LocationFix? _origin;
  bool _hasMoved = false;
  int _awayFromOrigin = 0;
  int _drivingInARow = 0;

  // Prolonged stop.
  _Stop? _stop;
  bool _stopOpen = false;

  /// When this engine last saw the vehicle move on: two readings at "moving
  /// again" speed, or leaving a stop. Null until then.
  DateTime? get lastMovingAt => _lastMovingAt;
  DateTime? _lastMovingAt;

  // Tracking.
  DateTime? _startedAt;
  DateTime? _lastFixAt;
  LocationFix? _lastFix;
  DateTime? _lastTickAt;
  InterruptionCause? _interruption;

  /// The recording began or resumed. [lastFixBefore] is the last fix of a
  /// recording the app was closed in the middle of.
  List<DetectorOutput> started(DateTime at, {DateTime? lastFixBefore}) {
    _startedAt = at;
    _lastTickAt = at;
    if (_interruption != null ||
        lastFixBefore == null ||
        at.difference(lastFixBefore) < config.signalLostAfter) {
      return const <DetectorOutput>[];
    }
    return _interrupt(InterruptionCause.appClosed, lastFixBefore, at);
  }

  /// The tracker's fix, as it arrived at [now].
  List<DetectorOutput> fix(LocationFix fix, DateTime now) {
    final Duration age = now.difference(fix.at);
    final LocationFix? previous = _lastFix;
    if (!_validPosition(fix) ||
        fix.accuracy > config.maxPositionAccuracy ||
        age > config.maxFixAge ||
        age.isNegative && age.abs() > config.maxFixAge ||
        // A repeat, or one that arrived late: time only moves forward here.
        (previous != null && !fix.at.isAfter(previous.at))) {
      return const <DetectorOutput>[];
    }
    final List<DetectorOutput> out = <DetectorOutput>[];
    if (_interruption != null) {
      _interruption = null;
      out.add(
        IncidentCleared(
          IncidentType.trackingInterrupted,
          IncidentResolution.trackingRestored,
          now,
        ),
      );
    }
    _lastFix = fix;
    _lastFixAt = fix.at;
    final _Reading? reading = _trustedSpeed(fix);
    final _Reading? before = _recent.isEmpty ? null : _recent.last;
    _noteMovement(fix, reading);
    if (reading != null && _movingAgain(reading, before)) {
      _lastMovingAt = fix.at;
    }
    out
      ..addAll(_deceleration(fix, reading, before))
      ..addAll(_prolongedStop(fix, reading, before, now));
    if (reading != null) _remember(reading);
    return out;
  }

  /// The tracker's periodic tick: signal loss, a suspended app, an expired
  /// deceleration candidate.
  List<DetectorOutput> tick(DateTime now) {
    final List<DetectorOutput> out = <DetectorOutput>[];
    final DateTime? lastTick = _lastTickAt;
    _lastTickAt = now;
    final _Candidate? c = _candidate;
    if (c != null && now.difference(c.lastAt) > config.confirmTimeout) {
      _candidate = null; // No fixes to confirm it: not an event.
    }
    if (_interruption != null) return out;
    if (lastTick != null && now.difference(lastTick) >= config.suspendedGap) {
      return out
        ..addAll(_interrupt(InterruptionCause.appSuspended, lastTick, now));
    }
    final DateTime? since = _lastFixAt ?? _startedAt;
    if (since != null && now.difference(since) >= config.signalLostAfter) {
      out.addAll(_interrupt(InterruptionCause.signalLost, since, now));
    }
    return out;
  }

  /// Location permission was taken away or the services were turned off.
  List<DetectorOutput> interrupted(InterruptionCause cause, DateTime at) {
    if (_interruption == cause) return const <DetectorOutput>[];
    return _interrupt(cause, _lastFixAt ?? at, at);
  }

  List<DetectorOutput> _interrupt(
    InterruptionCause cause,
    DateTime since,
    DateTime now,
  ) {
    _interruption = cause;
    // Without data nothing about movement can be concluded.
    _candidate = null;
    _stop = null;
    final LocationFix? last = _lastFix;
    return <DetectorOutput>[
      IncidentDetected(
        IncidentSignal(
          type: IncidentType.trackingInterrupted,
          // Missing data is never evidence of an incident.
          confidence: IncidentConfidence.low,
          at: now,
          reason: 'tracking interrupted: ${cause.name}',
          duration: now.difference(since),
          lat: last?.latitude,
          lng: last?.longitude,
          accuracy: last?.accuracy,
          fixAge: last == null ? null : now.difference(last.at),
          interruption: cause,
        ),
      ),
    ];
  }

  _Reading? _trustedSpeed(LocationFix fix) {
    final double? speed = fix.speed;
    final double? reported = fix.speedAccuracy;
    // Zero or less is how some phones say "unknown": never "precise".
    final double? error = reported != null && reported > 0 ? reported : null;
    if (speed == null ||
        !speed.isFinite ||
        speed < 0 ||
        fix.accuracy > config.maxSpeedAccuracy ||
        (reported != null &&
            (reported.isNaN || reported > config.maxSpeedError))) {
      return null;
    }
    return _Reading(fix, speed, error);
  }

  /// The journey has set off once it is far from where it started, or
  /// driving — each seen in [IncidentDetectionConfig.agreeingFixes] fixes in
  /// a row, so one jumped position or one wild speed cannot arm the stop.
  void _noteMovement(LocationFix fix, _Reading? reading) {
    final LocationFix origin = _origin ??= fix;
    if (_hasMoved) return;
    final bool far =
        _distance(origin, fix.latitude, fix.longitude) >= config.movedDistance;
    _awayFromOrigin = far ? _awayFromOrigin + 1 : 0;
    if (reading != null) {
      _drivingInARow = reading.speed >= config.movingSpeed
          ? _drivingInARow + 1
          : 0;
    }
    _hasMoved =
        _awayFromOrigin >= config.agreeingFixes ||
        _drivingInARow >= config.agreeingFixes;
  }

  List<DetectorOutput> _deceleration(
    LocationFix fix,
    _Reading? r,
    _Reading? before,
  ) {
    final List<DetectorOutput> out = <DetectorOutput>[];
    final _Candidate? c = _candidate;
    if (c != null) {
      final IncidentSignal? signal = _confirm(c, fix, r);
      if (signal != null) out.add(IncidentDetected(signal));
    }

    if (_decelerationOpen && r != null && _movingAgain(r, before)) {
      _decelerationOpen = false;
      out.add(
        IncidentCleared(
          IncidentType.suddenDeceleration,
          IncidentResolution.movementResumed,
          r.at,
        ),
      );
    }

    if (r == null ||
        _decelerationOpen ||
        _candidate != null ||
        before == null) {
      return out;
    }
    final double dt = r.at.difference(before.at).inMilliseconds / 1000;
    if (dt <= 0 || dt > config.decelerationWindow.inMilliseconds / 1000) {
      return out;
    }
    if (before.speed < config.movingSpeed || r.speed > config.stoppedSpeed) {
      return out;
    }
    final double deceleration = (before.speed - r.speed) / dt;
    if (deceleration < config.minDeceleration) return out;
    // The positions must agree with the speeds, or one of them is a glitch.
    final double moved = _distance(before.fix, r.fix.latitude, r.fix.longitude);
    final double expected = (before.speed + r.speed) / 2 * dt;
    final double tolerance =
        expected * 0.6 + before.fix.accuracy + r.fix.accuracy;
    if ((moved - expected).abs() > tolerance) return out;
    _candidate = _Candidate(
      before: before,
      after: r,
      deceleration: deceleration,
      drivingBefore: _recent
          .where(
            (_Reading x) =>
                r.at.difference(x.at) <= config.sustainWindow &&
                x.speed >= config.movingSpeed * 0.8,
          )
          .length,
    );
    return out;
  }

  /// One more fix while a drop waits: it either drove on, gets reported, or
  /// keeps waiting. Strong evidence is reported at
  /// [IncidentDetectionConfig.confirmStill]; anything weaker waits for
  /// [IncidentDetectionConfig.confirmStillUnsure].
  IncidentSignal? _confirm(_Candidate c, LocationFix fix, _Reading? r) {
    final double reach = math.max(config.confirmRadius, 2 * fix.accuracy);
    c
      ..outside = _distance(c.after.fix, fix.latitude, fix.longitude) > reach
          ? c.outside + 1
          : 0
      ..creeping = r != null && r.speed > config.stillSpeed
          ? c.creeping + 1
          : r == null
          ? c.creeping
          : 0;
    // Drove on, crawled on with traffic, or simply left: not an incident.
    if ((r != null && r.speed > config.resumeSpeed) ||
        c.outside >= config.agreeingFixes ||
        c.creeping >= config.agreeingFixes) {
      _candidate = null;
      return null;
    }
    c.add(fix);
    final Duration stillFor = fix.at.difference(c.after.at);
    if (stillFor < config.confirmStill) return null;
    final IncidentConfidence confidence = IncidentConfidenceRules.deceleration(
      c.evidence(stillFor, config.preciseSpeedError),
      config,
    );
    if (confidence != IncidentConfidence.high &&
        stillFor < config.confirmStillUnsure) {
      return null;
    }
    _candidate = null;
    _decelerationOpen = true;
    if (confidence != IncidentConfidence.low) {
      _stoppedAfterDeceleration = c.after.at;
    }
    return _decelerationSignal(c, fix, confidence, stillFor);
  }

  IncidentSignal _decelerationSignal(
    _Candidate c,
    LocationFix confirmedBy,
    IncidentConfidence confidence,
    Duration stillFor,
  ) {
    final double seconds =
        c.after.at.difference(c.before.at).inMilliseconds / 1000;
    return IncidentSignal(
      type: IncidentType.suddenDeceleration,
      confidence: confidence,
      at: confirmedBy.at,
      reason:
          'speed fell ${c.before.speed.toStringAsFixed(1)} → '
          '${c.after.speed.toStringAsFixed(1)} m/s in '
          '${seconds.toStringAsFixed(1)} s '
          '(${c.deceleration.toStringAsFixed(1)} m/s²), then stayed put for '
          '${stillFor.inSeconds} s over ${c.fixes} fixes',
      speedBefore: c.before.speed,
      speedAfter: c.after.speed,
      deceleration: c.deceleration,
      duration: stillFor,
      lat: c.after.fix.latitude,
      lng: c.after.fix.longitude,
      accuracy: c.worstAccuracy,
      fixAge: Duration.zero,
    );
  }

  List<DetectorOutput> _prolongedStop(
    LocationFix fix,
    _Reading? r,
    _Reading? before,
    DateTime now,
  ) {
    final _Stop? stop = _stop;
    final double radius = math.max(config.stopRadius, 2 * fix.accuracy);
    final double fromAnchor = stop == null
        ? 0
        : _distance(stop.anchor, fix.latitude, fix.longitude);
    if (stop != null) {
      stop.away = fromAnchor > math.max(config.resumeDistance, 2 * fix.accuracy)
          ? stop.away + 1
          : 0;
    }
    final bool leaving =
        stop != null && stop.away >= config.agreeingFixes ||
        (r != null && _movingAgain(r, before));
    if (leaving) {
      _stop = null;
      _lastMovingAt = fix.at;
      if (_stopOpen) {
        _stopOpen = false;
        return <DetectorOutput>[
          IncidentCleared(
            IncidentType.prolongedStop,
            IncidentResolution.movementResumed,
            fix.at,
          ),
        ];
      }
      return const <DetectorOutput>[];
    }
    if (stop != null && stop.away > 0) {
      return const <DetectorOutput>[]; // One fix away: wait for the next.
    }
    final bool still =
        (r == null || r.speed <= config.stillSpeed) && fromAnchor <= radius;
    if (!still) {
      // Inching forward: not still, not gone. A queue does this; someone who
      // cannot move does not. One noisy reading is not a creep.
      if (stop != null && ++stop.creepRun == config.agreeingFixes) {
        stop.creeps += 1;
      }
      return const <DetectorOutput>[];
    }
    if (stop == null || fix.at.difference(stop.lastAt) > config.maxFixGap) {
      // A new stop — or the data had a gap, and a gap is not "still".
      _stop = _Stop(fix);
      return const <DetectorOutput>[];
    }
    stop
      ..creepRun = 0
      ..add(fix);
    if (_stopOpen || !_hasMoved) return const <DetectorOutput>[];
    final Duration duration = fix.at.difference(stop.since);
    if (duration < config.stopDuration) return const <DetectorOutput>[];
    _stopOpen = true;
    final DateTime? stoppedAt = _stoppedAfterDeceleration;
    final StopEvidence evidence = StopEvidence(
      worstAccuracy: stop.worstAccuracy,
      longestGap: stop.longestGap,
      creeps: stop.creeps,
      atDestination: _atDestination(stop.anchor),
      afterDeceleration:
          stoppedAt != null &&
          stop.since.difference(stoppedAt).abs() <=
              config.stopAfterDeceleration,
    );
    return <DetectorOutput>[
      IncidentDetected(
        IncidentSignal(
          type: IncidentType.prolongedStop,
          confidence: IncidentConfidenceRules.stop(evidence, config),
          at: fix.at,
          reason:
              'still within ${radius.toStringAsFixed(0)} m for '
              '${duration.inSeconds} s after moving'
              '${evidence.afterDeceleration ? ', after a sudden deceleration' : ''}'
              '${evidence.creeps > 0 ? ', crept ${evidence.creeps}×' : ''}'
              '${evidence.atDestination ? ', at the destination' : ''}',
          speedAfter: r?.speed,
          duration: duration,
          lat: stop.anchor.latitude,
          lng: stop.anchor.longitude,
          accuracy: stop.worstAccuracy,
          fixAge: now.difference(fix.at),
        ),
      ),
    ];
  }

  bool _atDestination(LocationFix anchor) {
    final IncidentPlace? place = destination;
    return place != null &&
        RouteMath.distance(
              place.latitude,
              place.longitude,
              anchor.latitude,
              anchor.longitude,
            ) <=
            config.arrivalRadius + anchor.accuracy;
  }

  /// Two readings in a row at "moving again" speed.
  bool _movingAgain(_Reading r, _Reading? before) =>
      r.speed >= config.resumeSpeed &&
      before != null &&
      before.speed >= config.resumeSpeed;

  void _remember(_Reading r) {
    _recent
      ..add(r)
      ..removeWhere(
        (_Reading x) => r.at.difference(x.at) > config.sustainWindow,
      );
  }

  static double _distance(LocationFix from, double lat, double lng) =>
      RouteMath.distance(from.latitude, from.longitude, lat, lng);

  static bool _validPosition(LocationFix fix) =>
      fix.latitude.isFinite &&
      fix.longitude.isFinite &&
      fix.latitude.abs() <= 90 &&
      fix.longitude.abs() <= 180 &&
      !(fix.latitude == 0 && fix.longitude == 0) &&
      fix.accuracy > 0;
}

final class _Reading {
  const _Reading(this.fix, this.speed, this.error);

  final LocationFix fix;
  final double speed;

  /// m/s, when the phone reported it.
  final double? error;

  DateTime get at => fix.at;
}

/// A drop, waiting to see whether the vehicle stays put.
final class _Candidate {
  _Candidate({
    required this.before,
    required this.after,
    required this.deceleration,
    required this.drivingBefore,
  }) : lastAt = after.at;

  final _Reading before;
  final _Reading after;
  final double deceleration;
  final int drivingBefore;

  DateTime lastAt;
  int fixes = 0;
  Duration longestGap = Duration.zero;

  /// Fixes in a row outside the radius, and readings in a row above "still".
  int outside = 0;
  int creeping = 0;

  double get worstAccuracy => math.max(before.fix.accuracy, after.fix.accuracy);

  void add(LocationFix fix) {
    final Duration gap = fix.at.difference(lastAt);
    if (gap > longestGap) longestGap = gap;
    lastAt = fix.at;
    fixes += 1;
  }

  /// [precise]: the speed error (m/s) a reading must report to count as
  /// precise.
  DecelerationEvidence evidence(Duration stillFor, double precise) =>
      DecelerationEvidence(
        deceleration: deceleration,
        drivingReadingsBefore: drivingBefore,
        worstAccuracy: worstAccuracy,
        preciseSpeeds:
            before.error != null &&
            after.error != null &&
            before.error! <= precise &&
            after.error! <= precise,
        stillFor: stillFor,
        fixesWhileStill: fixes,
        longestGapWhileStill: longestGap,
      );
}

final class _Stop {
  _Stop(this.anchor)
    : since = anchor.at,
      lastAt = anchor.at,
      worstAccuracy = anchor.accuracy;

  final LocationFix anchor;
  final DateTime since;
  DateTime lastAt;
  double worstAccuracy;
  Duration longestGap = Duration.zero;

  /// Fixes in a row beyond reach of [anchor].
  int away = 0;

  /// Times it inched forward, and fixes in a row of the current inching.
  int creeps = 0;
  int creepRun = 0;

  void add(LocationFix fix) {
    final Duration gap = fix.at.difference(lastAt);
    if (gap > longestGap) longestGap = gap;
    lastAt = fix.at;
    worstAccuracy = math.max(worstAccuracy, fix.accuracy);
  }
}
