// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JourneyPlace _$JourneyPlaceFromJson(Map<String, dynamic> json) =>
    _JourneyPlace(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
      placeId: json['placeId'] as String?,
    );

Map<String, dynamic> _$JourneyPlaceToJson(_JourneyPlace instance) =>
    <String, dynamic>{
      'name': instance.name,
      'lat': instance.lat,
      'lng': instance.lng,
      'address': instance.address,
      'placeId': instance.placeId,
    };
