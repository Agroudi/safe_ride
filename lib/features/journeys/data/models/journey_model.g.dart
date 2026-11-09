// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JourneyModel _$JourneyModelFromJson(
  Map<String, dynamic> json,
) => _JourneyModel(
  id: json['id'] as String,
  origin: json['origin'] as String,
  destination: json['destination'] as String,
  status: $enumDecode(_$JourneyStatusEnumMap, json['status']),
  departsAt: const TimestampConverter().fromJson(json['departsAt']),
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  updatedAt: const TimestampConverter().fromJson(json['updatedAt']),
  startedAt: const NullableTimestampConverter().fromJson(json['startedAt']),
  originPlace: const JourneyPlaceConverter().fromJson(json['originPlace']),
  destinationPlace: const JourneyPlaceConverter().fromJson(
    json['destinationPlace'],
  ),
  plannedDistanceMeters: (json['plannedDistanceMeters'] as num?)?.toDouble(),
  plannedDurationSeconds: (json['plannedDurationSeconds'] as num?)?.toDouble(),
);

Map<String, dynamic> _$JourneyModelToJson(
  _JourneyModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'origin': instance.origin,
  'destination': instance.destination,
  'status': _$JourneyStatusEnumMap[instance.status]!,
  'departsAt': const TimestampConverter().toJson(instance.departsAt),
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
  'startedAt': const NullableTimestampConverter().toJson(instance.startedAt),
  'originPlace': const JourneyPlaceConverter().toJson(instance.originPlace),
  'destinationPlace': const JourneyPlaceConverter().toJson(
    instance.destinationPlace,
  ),
  'plannedDistanceMeters': instance.plannedDistanceMeters,
  'plannedDurationSeconds': instance.plannedDurationSeconds,
};

const _$JourneyStatusEnumMap = {
  JourneyStatus.planned: 'planned',
  JourneyStatus.active: 'active',
  JourneyStatus.completed: 'completed',
  JourneyStatus.cancelled: 'cancelled',
};
