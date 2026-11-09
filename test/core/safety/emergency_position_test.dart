import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 8, 9);

  PositionReading at(Duration ago, {double? accuracy = 8}) => PositionReading(
    latitude: 24.7136,
    longitude: 46.6753,
    at: now.subtract(ago),
    accuracy: accuracy,
  );

  group('freshness', () {
    test('within 20 seconds it is the current location', () {
      expect(at(Duration.zero).freshness(now), PositionFreshness.current);
      expect(
        at(PositionReading.currentFor).freshness(now),
        PositionFreshness.current,
      );
    });

    test('older, it is only the last known location', () {
      expect(
        at(const Duration(seconds: 21)).freshness(now),
        PositionFreshness.lastKnown,
      );
      expect(
        at(PositionReading.staleAfter).freshness(now),
        PositionFreshness.lastKnown,
      );
    });

    test('past five minutes it is stale', () {
      expect(
        at(const Duration(minutes: 5, seconds: 1)).freshness(now),
        PositionFreshness.stale,
      );
    });

    test('a fix stamped ahead of the clock is never older than none, and '
        'never called current: the two clocks disagree', () {
      expect(at(const Duration(seconds: -30)).age(now), Duration.zero);
      expect(
        at(const Duration(seconds: -30)).freshness(now),
        PositionFreshness.lastKnown,
      );
      expect(
        at(const Duration(seconds: -1)).freshness(now),
        PositionFreshness.current,
        reason: 'a second of jitter is not a disagreement',
      );
    });
  });

  group('accuracy', () {
    test('good, rough, poor, unknown', () {
      expect(at(Duration.zero, accuracy: 20).quality, PositionAccuracy.good);
      expect(at(Duration.zero, accuracy: 21).quality, PositionAccuracy.rough);
      expect(at(Duration.zero, accuracy: 100).quality, PositionAccuracy.rough);
      expect(at(Duration.zero, accuracy: 101).quality, PositionAccuracy.poor);
      expect(
        at(Duration.zero, accuracy: null).quality,
        PositionAccuracy.unknown,
      );
      expect(at(Duration.zero, accuracy: 0).quality, PositionAccuracy.unknown);
    });
  });

  test('0,0 and impossible positions are not positions', () {
    PositionReading p(double lat, double lng) =>
        PositionReading(latitude: lat, longitude: lng, at: now);
    expect(p(24.7, 46.7).valid, isTrue);
    expect(p(0, 0).valid, isFalse);
    expect(p(91, 0).valid, isFalse);
    expect(p(0, 181).valid, isFalse);
    expect(p(double.nan, 1).valid, isFalse);
  });
}
