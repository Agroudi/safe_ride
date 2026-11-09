import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'journey_place.freezed.dart';
part 'journey_place.g.dart';

/// A place picked on the map or from a search. The journey's own `origin`
/// and `destination` stay the user's words; this adds where they are.
@freezed
abstract class JourneyPlace with _$JourneyPlace {
  const factory JourneyPlace({
    required String name,
    required double lat,
    required double lng,

    /// The provider's fuller description, when it gave one.
    String? address,

    /// The provider's id for the place, when it has one.
    String? placeId,
  }) = _JourneyPlace;

  const JourneyPlace._();

  factory JourneyPlace.fromJson(Map<String, dynamic> json) =>
      _$JourneyPlaceFromJson(json);

  LatLng get point => LatLng(lat, lng);

  /// Real coordinates: in range, and not the 0,0 a failed reading gives.
  static bool validCoordinates(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);
}

/// A stored place, or null for a journey that has none (every journey from
/// before maps) or one whose coordinates cannot be trusted. A bad place
/// never costs the journey it belongs to.
class JourneyPlaceConverter implements JsonConverter<JourneyPlace?, Object?> {
  const JourneyPlaceConverter();

  @override
  JourneyPlace? fromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final JourneyPlace place = JourneyPlace.fromJson(
        Map<String, dynamic>.from(value),
      );
      return JourneyPlace.validCoordinates(place.lat, place.lng) ? place : null;
    } on Object {
      return null;
    }
  }

  @override
  Object? toJson(JourneyPlace? value) => value?.toJson();
}
