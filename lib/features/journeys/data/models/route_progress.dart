import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';

/// How far along a planned route someone is. Only ever given when it can be
/// trusted, because an invented figure is worse than none.
final class RouteProgress extends Equatable {
  const RouteProgress({required this.remainingMeters, this.remainingSeconds});

  final double remainingMeters;

  /// The provider's estimate, scaled to what is left. Null without one.
  final double? remainingSeconds;

  /// Further than this from the planned route, the driver has left it.
  static const double maxOffRouteMeters = 150;

  static const Distance _distance = Distance();

  /// Null when [position] is off [route], or the route is too short to say.
  static RouteProgress? along(PlannedRoute route, LatLng position) {
    final List<LatLng> points = route.points;
    if (points.length < 2) return null;
    double best = double.infinity;
    int bestSegment = 0;
    double bestFraction = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final (double metres, double fraction) = _toSegment(
        position,
        points[i],
        points[i + 1],
      );
      if (metres < best) {
        best = metres;
        bestSegment = i;
        bestFraction = fraction;
      }
    }
    if (best > maxOffRouteMeters) return null;
    double remaining =
        _distance(points[bestSegment], points[bestSegment + 1]) *
        (1 - bestFraction);
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final double length = _distance(points[i], points[i + 1]);
      total += length;
      if (i > bestSegment) remaining += length;
    }
    if (total <= 0) return null;
    final double? seconds = route.durationSeconds;
    return RouteProgress(
      remainingMeters: remaining,
      remainingSeconds: seconds == null ? null : seconds * remaining / total,
    );
  }

  /// Metres from [p] to the segment [a]–[b], and how far along it the
  /// nearest point lies (0–1). Flat-earth maths: segments are short.
  static (double, double) _toSegment(LatLng p, LatLng a, LatLng b) {
    final double scale = math.cos(p.latitudeInRad);
    final double bx = (b.longitude - a.longitude) * scale;
    final double by = b.latitude - a.latitude;
    final double px = (p.longitude - a.longitude) * scale;
    final double py = p.latitude - a.latitude;
    final double length = bx * bx + by * by;
    final double t = length == 0
        ? 0
        : ((px * bx + py * by) / length).clamp(0.0, 1.0);
    final LatLng nearest = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    return (_distance(p, nearest), t);
  }

  @override
  List<Object?> get props => <Object?>[remainingMeters, remainingSeconds];
}
