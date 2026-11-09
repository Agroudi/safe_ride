import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';

/// A route the routing provider suggested. An estimate, never a promise: the
/// provider knows the road network, not today's traffic.
final class PlannedRoute extends Equatable {
  const PlannedRoute({
    required this.points,
    required this.distanceMeters,
    this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;

  /// Null when the provider gave no estimate.
  final double? durationSeconds;

  @override
  List<Object?> get props => <Object?>[points, distanceMeters, durationSeconds];
}

/// Why a map provider gave nothing.
/// What the planner has picked, for the page to save.
typedef PlannedPlaces = ({
  JourneyPlace? origin,
  JourneyPlace? destination,
  PlannedRoute? route,
});

enum MapFailureCode {
  /// The phone could not reach the provider.
  offline,

  /// The provider answered badly, or refused for now.
  unavailable,

  /// The provider found no road between the two places.
  noRoute,

  /// The request was dropped for a newer one. Never shown.
  cancelled,
}

class MapFailure implements Exception {
  const MapFailure(this.code);

  final MapFailureCode code;

  @override
  String toString() => 'MapFailure(${code.name})';
}
