// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JourneyModel _$JourneyModelFromJson(Map<String, dynamic> json) =>
    _JourneyModel(
      id: json['id'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      status: $enumDecode(_$JourneyStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      departsAt: json['departsAt'] == null
          ? null
          : DateTime.parse(json['departsAt'] as String),
    );

Map<String, dynamic> _$JourneyModelToJson(_JourneyModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'origin': instance.origin,
      'destination': instance.destination,
      'status': _$JourneyStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'departsAt': instance.departsAt?.toIso8601String(),
    };

const _$JourneyStatusEnumMap = {
  JourneyStatus.planned: 'planned',
  JourneyStatus.completed: 'completed',
  JourneyStatus.cancelled: 'cancelled',
};
