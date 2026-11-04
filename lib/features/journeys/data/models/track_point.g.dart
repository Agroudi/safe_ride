// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrackPoint _$TrackPointFromJson(Map<String, dynamic> json) => _TrackPoint(
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  at: DateTime.parse(json['at'] as String),
  accuracy: (json['accuracy'] as num).toDouble(),
  speed: (json['speed'] as num?)?.toDouble(),
  segment: (json['segment'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TrackPointToJson(_TrackPoint instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'at': instance.at.toIso8601String(),
      'accuracy': instance.accuracy,
      'speed': instance.speed,
      'segment': instance.segment,
    };
