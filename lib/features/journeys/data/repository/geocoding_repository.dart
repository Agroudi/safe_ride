import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';

/// Names to places and back. `PhotonGeocodingRepository` implements it; a
/// paid provider would be one more, chosen in the service locator. Throws
/// only `MapFailure`.
abstract interface class GeocodingRepository {
  /// Places matching [query], best first. Results lean towards [near] when
  /// given. [cancel] completing drops the request.
  Future<List<JourneyPlace>> search(
    String query, {
    required String languageCode,
    LatLng? near,
    Future<void>? cancel,
  });

  /// What is at [point]; null when the provider knows nothing there.
  Future<JourneyPlace?> reverse(LatLng point, {required String languageCode});
}
