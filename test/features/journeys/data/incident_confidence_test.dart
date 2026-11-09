import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/incident_confidence.dart';
import 'package:safe_ride/features/journeys/data/models/incident_detection_config.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';

/// The confidence rules, one condition at a time: each test starts from
/// evidence that qualifies and takes away exactly one thing.
void main() {
  const IncidentDetectionConfig c = IncidentDetectionConfig();

  DecelerationEvidence drop({
    double deceleration = 8,
    int driving = 3,
    double accuracy = 5,
    bool precise = true,
    Duration stillFor = const Duration(seconds: 15),
    int fixes = 7,
    Duration gap = const Duration(seconds: 2),
  }) => DecelerationEvidence(
    deceleration: deceleration,
    drivingReadingsBefore: driving,
    worstAccuracy: accuracy,
    preciseSpeeds: precise,
    stillFor: stillFor,
    fixesWhileStill: fixes,
    longestGapWhileStill: gap,
  );

  IncidentConfidence rate(DecelerationEvidence e) =>
      IncidentConfidenceRules.deceleration(e, c);

  group('a sudden deceleration', () {
    test('high needs everything at once', () {
      expect(rate(drop()), IncidentConfidence.high);
    });

    test('each missing piece takes high away', () {
      expect(rate(drop(deceleration: 6.9)), isNot(IncidentConfidence.high));
      expect(rate(drop(driving: 1)), isNot(IncidentConfidence.high));
      expect(rate(drop(accuracy: 11)), isNot(IncidentConfidence.high));
      expect(rate(drop(precise: false)), isNot(IncidentConfidence.high));
      expect(rate(drop(fixes: 4)), isNot(IncidentConfidence.high));
      expect(
        rate(drop(gap: const Duration(seconds: 7))),
        isNot(IncidentConfidence.high),
      );
    });

    test('medium needs the longer stillness', () {
      expect(rate(drop(precise: false, accuracy: 12)), IncidentConfidence.low);
      expect(
        rate(
          drop(precise: false, accuracy: 12, stillFor: c.confirmStillUnsure),
        ),
        IncidentConfidence.medium,
      );
    });

    test('one reading of driving speed is never more than low', () {
      expect(
        rate(drop(driving: 1, stillFor: const Duration(minutes: 5))),
        IncidentConfidence.low,
      );
    });

    test('poor accuracy, a weak drop or a long gap: low', () {
      const Duration long = Duration(minutes: 1);
      expect(rate(drop(accuracy: 16, stillFor: long)), IncidentConfidence.low);
      expect(
        rate(drop(deceleration: 5, precise: false, stillFor: long)),
        IncidentConfidence.low,
      );
      expect(
        rate(
          drop(
            precise: false,
            stillFor: long,
            gap: const Duration(seconds: 31),
          ),
        ),
        IncidentConfidence.low,
      );
    });

    test('the same evidence always gives the same answer', () {
      final DecelerationEvidence e = drop(
        precise: false,
        stillFor: c.confirmStillUnsure,
      );
      expect(
        List<IncidentConfidence>.generate(5, (_) => rate(e)).toSet(),
        hasLength(1),
      );
    });
  });

  group('a long stop', () {
    StopEvidence stop({
      double accuracy = 5,
      Duration gap = const Duration(seconds: 2),
      int creeps = 0,
      bool atDestination = false,
      bool afterDeceleration = false,
    }) => StopEvidence(
      worstAccuracy: accuracy,
      longestGap: gap,
      creeps: creeps,
      atDestination: atDestination,
      afterDeceleration: afterDeceleration,
    );

    IncidentConfidence rateStop(StopEvidence e) =>
        IncidentConfidenceRules.stop(e, c);

    test('alone it is medium; after a real deceleration, high', () {
      expect(rateStop(stop()), IncidentConfidence.medium);
      expect(rateStop(stop(afterDeceleration: true)), IncidentConfidence.high);
    });

    test('poor data, a queue or the destination makes it low, even after a '
        'deceleration', () {
      for (final StopEvidence e in <StopEvidence>[
        stop(accuracy: 16, afterDeceleration: true),
        stop(gap: const Duration(seconds: 31), afterDeceleration: true),
        stop(creeps: 2, afterDeceleration: true),
        stop(atDestination: true, afterDeceleration: true),
      ]) {
        expect(rateStop(e), IncidentConfidence.low);
      }
      expect(rateStop(stop(creeps: 1)), IncidentConfidence.medium);
    });
  });
}
