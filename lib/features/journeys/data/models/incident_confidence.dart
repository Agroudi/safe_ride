import 'package:safe_ride/features/journeys/data/models/incident_detection_config.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';

/// What the data showed about a sudden deceleration, once it had lasted.
final class DecelerationEvidence {
  const DecelerationEvidence({
    required this.deceleration,
    required this.drivingReadingsBefore,
    required this.worstAccuracy,
    required this.preciseSpeeds,
    required this.stillFor,
    required this.fixesWhileStill,
    required this.longestGapWhileStill,
  });

  /// m/s², between the two readings of the drop.
  final double deceleration;

  /// Readings at driving speed in the window before the drop.
  final int drivingReadingsBefore;

  /// The worse accuracy (metres) of the drop's two fixes.
  final double worstAccuracy;

  /// Both readings of the drop came with a speed error the phone reported,
  /// within `preciseSpeedError`. Unknown is never precise.
  final bool preciseSpeeds;

  /// How long it has stayed put since the drop.
  final Duration stillFor;

  /// Fixes that showed it staying put, and the longest wait between them.
  final int fixesWhileStill;
  final Duration longestGapWhileStill;
}

/// What the data showed about a long stop.
final class StopEvidence {
  const StopEvidence({
    required this.worstAccuracy,
    required this.longestGap,
    required this.creeps,
    required this.atDestination,
    required this.afterDeceleration,
  });

  final double worstAccuracy;
  final Duration longestGap;

  /// Times it inched forward and stopped again: a queue, not someone who
  /// cannot move.
  final int creeps;

  /// Within reach of the journey's planned destination: it has arrived.
  final bool atDestination;

  /// It began right after a sudden deceleration of medium or high confidence.
  final bool afterDeceleration;
}

/// How much the data supports a potential incident — never certainty, and
/// never "an accident". Pure functions of the evidence, so every rule is
/// tested on its own. **A threshold crossed alone is never high**: high needs
/// strength, good accuracy, reported precision, driving before, and steady
/// data after, all at once.
abstract final class IncidentConfidenceRules {
  /// - **high:** ≥ `highDeceleration`; driving in at least two readings
  ///   before; both fixes within `goodAccuracy`; both speed errors reported
  ///   and within `preciseSpeedError`; and since the drop at least
  ///   `confirmFixes` fixes, none more than `confirmGap` apart.
  /// - **medium:** ≥ `mediumDeceleration`; driving in two readings before;
  ///   both fixes within `mediumAccuracy`; still for `confirmStillUnsure`,
  ///   no gap over `steadyFixGap`.
  /// - **low:** anything else that got this far.
  static IncidentConfidence deceleration(
    DecelerationEvidence e,
    IncidentDetectionConfig c,
  ) {
    final bool drivingBefore = e.drivingReadingsBefore >= 2;
    if (drivingBefore &&
        e.deceleration >= c.highDeceleration &&
        e.worstAccuracy <= c.goodAccuracy &&
        e.preciseSpeeds &&
        e.fixesWhileStill >= c.confirmFixes &&
        e.longestGapWhileStill <= c.confirmGap) {
      return IncidentConfidence.high;
    }
    if (drivingBefore &&
        e.deceleration >= c.mediumDeceleration &&
        e.worstAccuracy <= c.mediumAccuracy &&
        e.stillFor >= c.confirmStillUnsure &&
        e.longestGapWhileStill <= c.steadyFixGap) {
      return IncidentConfidence.medium;
    }
    return IncidentConfidence.low;
  }

  /// A stop alone is at most medium: fuel, a shop, a friend.
  /// - **low:** fixes worse than `mediumAccuracy` or more than `steadyFixGap`
  ///   apart; or it crept forward `queueCreeps` times (traffic); or it is at
  ///   the destination.
  /// - **high:** otherwise, when it began right after a medium or high sudden
  ///   deceleration.
  /// - **medium:** otherwise.
  static IncidentConfidence stop(StopEvidence e, IncidentDetectionConfig c) {
    final bool steady =
        e.worstAccuracy <= c.mediumAccuracy && e.longestGap <= c.steadyFixGap;
    if (!steady || e.creeps >= c.queueCreeps || e.atDestination) {
      return IncidentConfidence.low;
    }
    return e.afterDeceleration
        ? IncidentConfidence.high
        : IncidentConfidence.medium;
  }
}
