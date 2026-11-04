import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/route_math.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';

LocationFix _fix(
  double lat,
  double lng, {
  required DateTime at,
  double accuracy = 8,
  double? speed,
  double? speedAccuracy,
}) => LocationFix(
  latitude: lat,
  longitude: lng,
  at: at,
  accuracy: accuracy,
  speed: speed,
  speedAccuracy: speedAccuracy,
);

void main() {
  final DateTime t0 = DateTime.utc(2026, 11, 1, 9);

  group('RouteMath.distance (haversine)', () {
    test('one degree of latitude is about 111.2 km', () {
      expect(RouteMath.distance(24, 46, 25, 46), closeTo(111195, 5));
    });

    test('a short hop in Riyadh matches the known value', () {
      // Two points on King Fahd Road, ~1.1 km apart north–south.
      expect(
        RouteMath.distance(24.7000, 46.6750, 24.7100, 46.6750),
        closeTo(1112, 2),
      );
    });

    test('the same point is no distance; order does not matter', () {
      expect(RouteMath.distance(24.7, 46.6, 24.7, 46.6), 0);
      expect(
        RouteMath.distance(24.7, 46.6, 24.8, 46.7),
        closeTo(RouteMath.distance(24.8, 46.7, 24.7, 46.6), 1e-6),
      );
    });
  });

  group('RouteFilter.judge', () {
    final TrackPoint last = TrackPoint(
      lat: 24.7,
      lng: 46.67,
      at: t0,
      accuracy: 8,
    );
    final DateTime now = t0.add(const Duration(seconds: 10));

    FixVerdict judge(LocationFix fix, [TrackPoint? previous]) =>
        RouteFilter.judge(fix, previous, now);

    test('the first good fix is accepted', () {
      expect(judge(_fix(24.7, 46.67, at: now)), FixVerdict.accepted);
    });

    test('out-of-range, NaN and 0,0 positions are invalid', () {
      expect(judge(_fix(91, 46, at: now)), FixVerdict.invalid);
      expect(judge(_fix(24, 181, at: now)), FixVerdict.invalid);
      expect(judge(_fix(double.nan, 46, at: now)), FixVerdict.invalid);
      expect(judge(_fix(0, 0, at: now)), FixVerdict.invalid);
    });

    test('an unknown or poor accuracy is not trusted', () {
      expect(
        judge(_fix(24.7, 46.67, at: now, accuracy: 0)),
        FixVerdict.inaccurate,
      );
      expect(
        judge(_fix(24.7, 46.67, at: now, accuracy: 51)),
        FixVerdict.inaccurate,
      );
      expect(
        judge(_fix(24.7, 46.67, at: now, accuracy: 50)),
        FixVerdict.accepted,
      );
    });

    test('a cached fix, or one older than the last point, is stale', () {
      expect(
        judge(_fix(24.7, 46.67, at: now.subtract(const Duration(minutes: 1)))),
        FixVerdict.stale,
      );
      expect(judge(_fix(24.71, 46.67, at: t0), last), FixVerdict.stale);
    });

    test('standing still or jitter under 5 m is a duplicate', () {
      expect(judge(_fix(24.70002, 46.67, at: now), last), FixVerdict.duplicate);
    });

    test('an impossible speed between two points is a jump', () {
      // ~11 km in 10 s.
      expect(judge(_fix(24.8, 46.67, at: now), last), FixVerdict.jump);
      // ~111 m in 10 s (40 km/h) is fine.
      expect(judge(_fix(24.701, 46.67, at: now), last), FixVerdict.accepted);
    });
  });

  group('SpeedSmoother', () {
    test('a fix without a speed, or with an unreliable one, gives none', () {
      final SpeedSmoother s = SpeedSmoother();
      expect(s.add(_fix(24.7, 46.6, at: t0)), isNull);
      expect(s.add(_fix(24.7, 46.6, at: t0, speed: -1)), isNull);
      expect(
        s.add(_fix(24.7, 46.6, at: t0, speed: 10, speedAccuracy: 5)),
        isNull,
      );
      expect(s.add(_fix(24.7, 46.6, at: t0, speed: 10, accuracy: 80)), isNull);
    });

    test('readings are smoothed; a jump moves the average part-way', () {
      final SpeedSmoother s = SpeedSmoother();
      expect(s.add(_fix(24.7, 46.6, at: t0, speed: 10)), 10);
      final double? next = s.add(
        _fix(24.7, 46.6, at: t0.add(const Duration(seconds: 5)), speed: 20),
      );
      expect(next, closeTo(14, 1e-9));
    });

    test('near zero is shown as standing still', () {
      final SpeedSmoother s = SpeedSmoother();
      expect(s.add(_fix(24.7, 46.6, at: t0, speed: 0.3)), 0);
    });

    test('a long gap starts the average again', () {
      final SpeedSmoother s = SpeedSmoother()
        ..add(_fix(24.7, 46.6, at: t0, speed: 30));
      expect(
        s.add(
          _fix(24.7, 46.6, at: t0.add(const Duration(minutes: 1)), speed: 5),
        ),
        5,
      );
    });
  });

  test('a fix far ahead of the clock is not trusted', () {
    final DateTime now = DateTime.utc(2026, 11, 4, 9);
    LocationFix at(Duration ahead) => LocationFix(
      latitude: 24.7,
      longitude: 46.67,
      at: now.add(ahead),
      accuracy: 8,
    );
    expect(
      RouteFilter.judge(at(const Duration(hours: 1)), null, now),
      FixVerdict.stale,
    );
    // A phone's clock can be a little wrong.
    expect(
      RouteFilter.judge(at(const Duration(minutes: 1)), null, now),
      FixVerdict.accepted,
    );
  });
}
