import 'dart:math' as math;

import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';

/// Great-circle distance on a sphere (haversine) — within about 0.5 % of the
/// true ellipsoid distance, far below GPS error at journey scales.
abstract final class RouteMath {
  /// The mean Earth radius (IUGG), metres.
  static const double earthRadius = 6371008.8;

  static double distance(double lat1, double lng1, double lat2, double lng2) {
    final double p1 = _rad(lat1);
    final double p2 = _rad(lat2);
    final double dp = _rad(lat2 - lat1);
    final double dl = _rad(lng2 - lng1);
    final double h =
        math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  static double between(TrackPoint a, TrackPoint b) =>
      distance(a.lat, a.lng, b.lat, b.lng);

  static double _rad(double degrees) => degrees * math.pi / 180;
}

/// Why a fix was, or was not, added to the route.
enum FixVerdict {
  accepted,

  /// Not a position at all (out of range, NaN, the 0,0 "null island").
  invalid,

  /// Less accurate than [RouteFilter.maxAccuracy].
  inaccurate,

  /// Older than the last trusted point, or a cached fix from long ago.
  stale,

  /// Within [RouteFilter.minMove] of the last trusted point: standing still,
  /// or GPS jitter.
  duplicate,

  /// Further from the last trusted point than [RouteFilter.maxSpeed] allows.
  jump,
}

/// Which fixes become route points. A fix that fails is not stored and adds
/// no distance; the tracker still uses it to tell a weak signal from none.
abstract final class RouteFilter {
  /// Fixes less accurate than this (metres) are not trusted.
  static const double maxAccuracy = 50;

  /// Fixes less accurate than this (metres) mean a weak signal.
  static const double weakAccuracy = 25;

  /// Closer than this (metres) to the last trusted point is no movement.
  static const double minMove = 5;

  /// Faster than this (m/s, 252 km/h) between two points is a GPS jump.
  static const double maxSpeed = 70;

  /// A fix older than this when it arrives is a cached one.
  static const Duration maxAge = Duration(seconds: 30);

  /// A fix further ahead of the phone's clock than this cannot be trusted:
  /// kept, it would make every real fix after it look old. Generous, because
  /// a phone's clock can be a little wrong.
  static const Duration maxAhead = Duration(minutes: 5);

  static FixVerdict judge(LocationFix fix, TrackPoint? last, DateTime now) {
    if (!_valid(fix.latitude, fix.longitude)) return FixVerdict.invalid;
    if (fix.accuracy <= 0 || fix.accuracy.isNaN || fix.accuracy > maxAccuracy) {
      return FixVerdict.inaccurate;
    }
    if (now.difference(fix.at) > maxAge) return FixVerdict.stale;
    if (fix.at.difference(now) > maxAhead) return FixVerdict.stale;
    if (last == null) return FixVerdict.accepted;
    if (!fix.at.isAfter(last.at)) return FixVerdict.stale;
    final double moved = RouteMath.distance(
      last.lat,
      last.lng,
      fix.latitude,
      fix.longitude,
    );
    if (moved < minMove) return FixVerdict.duplicate;
    final double seconds = fix.at.difference(last.at).inMilliseconds / 1000;
    if (moved / seconds > maxSpeed) return FixVerdict.jump;
    return FixVerdict.accepted;
  }

  static bool _valid(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);
}

/// The phone's speed readings, cleaned: only trustworthy ones, smoothed with
/// an exponential moving average, and near-zero noise shown as standing
/// still. SafeRide never derives a speed from positions alone — two noisy
/// fixes a few seconds apart give a misleading number.
final class SpeedSmoother {
  /// Weight of a new reading (the rest is the previous average).
  static const double weight = 0.4;

  /// A reading whose own error is above this (m/s) is not shown.
  static const double maxSpeedError = 3;

  /// Below this (m/s, 1.8 km/h) the phone is treated as standing still.
  static const double still = 0.5;

  /// A gap longer than this starts the average again.
  static const Duration reset = Duration(seconds: 15);

  double? _average;
  DateTime? _at;

  /// The smoothed speed (m/s) after [fix], or null when [fix] carries no
  /// trustworthy speed.
  double? add(LocationFix fix) {
    final double? speed = fix.speed;
    final double? error = fix.speedAccuracy;
    if (speed == null ||
        !speed.isFinite ||
        speed < 0 ||
        fix.accuracy <= 0 ||
        fix.accuracy > RouteFilter.maxAccuracy ||
        (error != null && error > maxSpeedError)) {
      return null;
    }
    final DateTime? previous = _at;
    final double? average = _average;
    _average =
        average == null ||
            previous == null ||
            fix.at.difference(previous) > reset
        ? speed
        : average + weight * (speed - average);
    _at = fix.at;
    return _average! < still ? 0 : _average;
  }

  void clear() {
    _average = null;
    _at = null;
  }
}
