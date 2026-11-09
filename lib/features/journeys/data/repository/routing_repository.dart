import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';

/// A route between two places. `OsrmRoutingRepository` implements it; another
/// provider would be one more, chosen in the service locator. Throws only
/// `MapFailure`. Only the two end points are ever sent: never a recorded
/// route.
abstract interface class RoutingRepository {
  Future<PlannedRoute> route(LatLng from, LatLng to);
}
