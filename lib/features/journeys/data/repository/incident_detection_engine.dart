import 'dart:math' as math;

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
/// scenario is tested with simulated fixes. It reads the tracker's own fixes
/// (no location subscription of its own) and keeps only a few seconds of
/// them.
///
/// **Conservative by design:** untrusted, stale or missing data never
/// produces an event; each condition is reported once until it clears; a
/// tracking interruption is never an incident of movement; confidence
/// rises only when accuracy, freshness, consistency and duration all agree.
class IncidentDetectionEngine {
  IncidentDetectionEngine({
    required this.journeyId,
    this.config = const IncidentDetectionConfig(),
  });

  final String journeyId;
  final IncidentDetectionConfig config;

  // Sudden deceleration.
  final List<_Reading> _recent = <_Reading>[];
  _Candidate? _candidate;
  bool _decelerationOpen = false;

  /// When the vehicle stood still after the last reported deceleration.
  DateTime? _stoppedAfterDeceleration;

  // Prolonged stop.
  LocationFix? _origin;
  bool _hasMoved = false;
  _Stop? _stop;
  bool _stopOpen = false;

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
    if (!_validPosition(fix) ||
        fix.accuracy > config.maxPositionAccuracy ||
        age > config.maxFixAge ||
        age.isNegative && age.abs() > config.maxFixAge) {
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
    final _Reading? reading = _trustedSpeed(fix, now);
    _noteMovement(fix, reading);
    out
      ..addAll(_deceleration(reading))
      ..addAll(_prolongedStop(fix, reading, now));
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
    if (c != null && now.difference(c.after.at) > config.confirmTimeout) {
      _candidate = null; // No readings to confirm it: not an event.
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

  _Reading? _trustedSpeed(LocationFix fix, DateTime now) {
    final double? speed = fix.speed;
    final double? error = fix.speedAccuracy;
    if (speed == null ||
        !speed.isFinite ||
        speed < 0 ||
        fix.accuracy > config.maxSpeedAccuracy ||
        (error != null && (error.isNaN || error > config.maxSpeedError))) {
      return null;
    }
    return _Reading(fix, speed, error);
  }

  void _noteMovement(LocationFix fix, _Reading? reading) {
    final LocationFix origin = _origin ??= fix;
    if (_hasMoved) return;
    _hasMoved =
        RouteMath.distance(
              origin.latitude,
              origin.longitude,
              fix.latitude,
              fix.longitude,
            ) >=
            config.movedDistance ||
        (reading != null && reading.speed >= config.movingSpeed);
  }

  List<DetectorOutput> _deceleration(_Reading? r) {
    if (r == null) return const <DetectorOutput>[];
    final List<DetectorOutput> out = <DetectorOutput>[];
    final _Reading? before = _recent.isEmpty ? null : _recent.last;

    final _Candidate? c = _candidate;
    if (c != null) {
      if (r.speed > config.resumeSpeed) {
        _candidate = null; // It drove on: a hard brake, or a glitch.
      } else if (r.at.difference(c.after.at) >= config.confirmStill) {
        _candidate = null;
        _decelerationOpen = true;
        _stoppedAfterDeceleration = c.after.at;
        out.add(IncidentDetected(_decelerationSignal(c, r)));
      }
    }

    if (_decelerationOpen && _movingAgain(r, before)) {
      _decelerationOpen = false;
      out.add(
        IncidentCleared(
          IncidentType.suddenDeceleration,
          IncidentResolution.movementResumed,
          r.at,
        ),
      );
    }

    if (_decelerationOpen || _candidate != null || before == null) return out;
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
    final double moved = RouteMath.distance(
      before.fix.latitude,
      before.fix.longitude,
      r.fix.latitude,
      r.fix.longitude,
    );
    final double expected = (before.speed + r.speed) / 2 * dt;
    final double tolerance =
        expected * 0.6 + before.fix.accuracy + r.fix.accuracy;
    if ((moved - expected).abs() > tolerance) return out;
    final int driving = _recent
        .where(
          (_Reading x) =>
              r.at.difference(x.at) <= config.sustainWindow &&
              x.speed >= config.movingSpeed * 0.8,
        )
        .length;
    _candidate = _Candidate(
      before: before,
      after: r,
      deceleration: deceleration,
      sustained: driving >= 2,
    );
    return out;
  }

  IncidentSignal _decelerationSignal(_Candidate c, _Reading confirmedBy) {
    final double worstAccuracy = math.max(
      c.before.fix.accuracy,
      c.after.fix.accuracy,
    );
    final bool speedErrorKnown =
        c.before.error != null && c.after.error != null;
    final bool precise =
        speedErrorKnown &&
        c.before.error! <= config.preciseSpeedError &&
        c.after.error! <= config.preciseSpeedError;
    final IncidentConfidence confidence =
        c.sustained &&
            c.deceleration >= config.highDeceleration &&
            worstAccuracy <= config.goodAccuracy &&
            precise
        ? IncidentConfidence.high
        : c.sustained &&
              c.deceleration >= config.mediumDeceleration &&
              worstAccuracy <= config.mediumAccuracy
        ? IncidentConfidence.medium
        : IncidentConfidence.low;
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
          '(${c.deceleration.toStringAsFixed(1)} m/s²), still for '
          '${confirmedBy.at.difference(c.after.at).inSeconds} s',
      speedBefore: c.before.speed,
      speedAfter: c.after.speed,
      deceleration: c.deceleration,
      duration: confirmedBy.at.difference(c.after.at),
      lat: c.after.fix.latitude,
      lng: c.after.fix.longitude,
      accuracy: worstAccuracy,
      fixAge: Duration.zero,
    );
  }

  List<DetectorOutput> _prolongedStop(
    LocationFix fix,
    _Reading? r,
    DateTime now,
  ) {
    final _Reading? before = _recent.isEmpty ? null : _recent.last;
    final _Stop? stop = _stop;
    final double radius = math.max(config.stopRadius, 2 * fix.accuracy);
    final double fromAnchor = stop == null
        ? 0
        : RouteMath.distance(
            stop.anchor.latitude,
            stop.anchor.longitude,
            fix.latitude,
            fix.longitude,
          );
    final bool leaving =
        stop != null &&
            fromAnchor > math.max(config.resumeDistance, 2 * fix.accuracy) ||
        (r != null && _movingAgain(r, before));
    if (leaving) {
      _stop = null;
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
    final bool still =
        (r == null || r.speed <= config.stillSpeed) && fromAnchor <= radius;
    if (!still) return const <DetectorOutput>[]; // Creeping: neither.
    if (stop == null || fix.at.difference(stop.lastAt) > config.maxFixGap) {
      // A new stop — or the data had a gap, and a gap is not "still".
      _stop = _Stop(fix);
      return const <DetectorOutput>[];
    }
    stop.add(fix);
    if (_stopOpen || !_hasMoved) return const <DetectorOutput>[];
    final Duration duration = fix.at.difference(stop.since);
    if (duration < config.stopDuration) return const <DetectorOutput>[];
    _stopOpen = true;
    final bool steady =
        stop.worstAccuracy <= config.mediumAccuracy &&
        stop.longestGap <= config.steadyFixGap;
    final DateTime? stoppedAt = _stoppedAfterDeceleration;
    final bool afterDeceleration =
        stoppedAt != null &&
        stop.since.difference(stoppedAt).abs() <= config.stopAfterDeceleration;
    return <DetectorOutput>[
      IncidentDetected(
        IncidentSignal(
          type: IncidentType.prolongedStop,
          // A stop alone is at most medium: fuel, a shop, a friend.
          confidence: steady && afterDeceleration
              ? IncidentConfidence.high
              : steady
              ? IncidentConfidence.medium
              : IncidentConfidence.low,
          at: fix.at,
          reason:
              'still within ${radius.toStringAsFixed(0)} m for '
              '${duration.inSeconds} s after moving'
              '${afterDeceleration ? ', after a sudden deceleration' : ''}',
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
  final double? error;

  DateTime get at => fix.at;
}

final class _Candidate {
  const _Candidate({
    required this.before,
    required this.after,
    required this.deceleration,
    required this.sustained,
  });

  final _Reading before;
  final _Reading after;
  final double deceleration;
  final bool sustained;
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

  void add(LocationFix fix) {
    final Duration gap = fix.at.difference(lastAt);
    if (gap > longestGap) longestGap = gap;
    lastAt = fix.at;
    worstAccuracy = math.max(worstAccuracy, fix.accuracy);
  }
}
