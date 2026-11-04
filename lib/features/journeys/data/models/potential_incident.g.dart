// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'potential_incident.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PotentialIncident _$PotentialIncidentFromJson(Map<String, dynamic> json) =>
    _PotentialIncident(
      id: json['id'] as String,
      journeyId: json['journeyId'] as String,
      uid: json['uid'] as String,
      type: $enumDecode(_$IncidentTypeEnumMap, json['type']),
      status: $enumDecode(_$IncidentStatusEnumMap, json['status']),
      confidence: $enumDecode(_$IncidentConfidenceEnumMap, json['confidence']),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reason: json['reason'] as String,
      speedBeforeKmh: (json['speedBeforeKmh'] as num?)?.toDouble(),
      speedAfterKmh: (json['speedAfterKmh'] as num?)?.toDouble(),
      deceleration: (json['deceleration'] as num?)?.toDouble(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      fixAgeSeconds: (json['fixAgeSeconds'] as num?)?.toDouble(),
      interruption: $enumDecodeNullable(
        _$InterruptionCauseEnumMap,
        json['interruption'],
      ),
      resolution: $enumDecodeNullable(
        _$IncidentResolutionEnumMap,
        json['resolution'],
      ),
      supersededBy: json['supersededBy'] as String?,
    );

Map<String, dynamic> _$PotentialIncidentToJson(_PotentialIncident instance) =>
    <String, dynamic>{
      'id': instance.id,
      'journeyId': instance.journeyId,
      'uid': instance.uid,
      'type': _$IncidentTypeEnumMap[instance.type]!,
      'status': _$IncidentStatusEnumMap[instance.status]!,
      'confidence': _$IncidentConfidenceEnumMap[instance.confidence]!,
      'detectedAt': instance.detectedAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'reason': instance.reason,
      'speedBeforeKmh': instance.speedBeforeKmh,
      'speedAfterKmh': instance.speedAfterKmh,
      'deceleration': instance.deceleration,
      'durationSeconds': instance.durationSeconds,
      'lat': instance.lat,
      'lng': instance.lng,
      'accuracyMeters': instance.accuracyMeters,
      'fixAgeSeconds': instance.fixAgeSeconds,
      'interruption': _$InterruptionCauseEnumMap[instance.interruption],
      'resolution': _$IncidentResolutionEnumMap[instance.resolution],
      'supersededBy': instance.supersededBy,
    };

const _$IncidentTypeEnumMap = {
  IncidentType.suddenDeceleration: 'suddenDeceleration',
  IncidentType.prolongedStop: 'prolongedStop',
  IncidentType.trackingInterrupted: 'trackingInterrupted',
};

const _$IncidentStatusEnumMap = {
  IncidentStatus.detected: 'detected',
  IncidentStatus.awaitingConfirmation: 'awaitingConfirmation',
  IncidentStatus.escalationReady: 'escalationReady',
  IncidentStatus.dismissed: 'dismissed',
  IncidentStatus.resolved: 'resolved',
  IncidentStatus.superseded: 'superseded',
};

const _$IncidentConfidenceEnumMap = {
  IncidentConfidence.low: 'low',
  IncidentConfidence.medium: 'medium',
  IncidentConfidence.high: 'high',
};

const _$InterruptionCauseEnumMap = {
  InterruptionCause.permissionRemoved: 'permissionRemoved',
  InterruptionCause.locationServicesOff: 'locationServicesOff',
  InterruptionCause.signalLost: 'signalLost',
  InterruptionCause.appSuspended: 'appSuspended',
  InterruptionCause.appClosed: 'appClosed',
};

const _$IncidentResolutionEnumMap = {
  IncidentResolution.movementResumed: 'movementResumed',
  IncidentResolution.trackingRestored: 'trackingRestored',
  IncidentResolution.journeyEnded: 'journeyEnded',
  IncidentResolution.dismissedByUser: 'dismissedByUser',
  IncidentResolution.replaced: 'replaced',
  IncidentResolution.confirmedSafe: 'confirmedSafe',
  IncidentResolution.checkCancelled: 'checkCancelled',
};
