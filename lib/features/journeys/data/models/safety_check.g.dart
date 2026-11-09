// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safety_check.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SafetyCheck _$SafetyCheckFromJson(Map<String, dynamic> json) => _SafetyCheck(
  id: json['id'] as String,
  incidentId: json['incidentId'] as String,
  journeyId: json['journeyId'] as String,
  uid: json['uid'] as String,
  status: $enumDecode(_$SafetyCheckStatusEnumMap, json['status']),
  startedAt: DateTime.parse(json['startedAt'] as String),
  deadline: DateTime.parse(json['deadline'] as String),
  incidentType: $enumDecodeNullable(
    _$IncidentTypeEnumMap,
    json['incidentType'],
  ),
  incidentConfidence: $enumDecodeNullable(
    _$IncidentConfidenceEnumMap,
    json['incidentConfidence'],
  ),
  incidentDetectedAt: json['incidentDetectedAt'] == null
      ? null
      : DateTime.parse(json['incidentDetectedAt'] as String),
  confirmedAt: json['confirmedAt'] == null
      ? null
      : DateTime.parse(json['confirmedAt'] as String),
  timedOutAt: json['timedOutAt'] == null
      ? null
      : DateTime.parse(json['timedOutAt'] as String),
  timeoutProcessedAt: json['timeoutProcessedAt'] == null
      ? null
      : DateTime.parse(json['timeoutProcessedAt'] as String),
  escalationReadyAt: json['escalationReadyAt'] == null
      ? null
      : DateTime.parse(json['escalationReadyAt'] as String),
  presentedAt: json['presentedAt'] == null
      ? null
      : DateTime.parse(json['presentedAt'] as String),
  resolvedAt: json['resolvedAt'] == null
      ? null
      : DateTime.parse(json['resolvedAt'] as String),
  resolution: $enumDecodeNullable(
    _$EscalationResolutionEnumMap,
    json['resolution'],
  ),
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  cancelReason: $enumDecodeNullable(
    _$SafetyCheckCancelReasonEnumMap,
    json['cancelReason'],
  ),
  escalationQueuedAt: json['escalationQueuedAt'] == null
      ? null
      : DateTime.parse(json['escalationQueuedAt'] as String),
  escalationSyncedAt: json['escalationSyncedAt'] == null
      ? null
      : DateTime.parse(json['escalationSyncedAt'] as String),
);

Map<String, dynamic> _$SafetyCheckToJson(_SafetyCheck instance) =>
    <String, dynamic>{
      'id': instance.id,
      'incidentId': instance.incidentId,
      'journeyId': instance.journeyId,
      'uid': instance.uid,
      'status': _$SafetyCheckStatusEnumMap[instance.status]!,
      'startedAt': instance.startedAt.toIso8601String(),
      'deadline': instance.deadline.toIso8601String(),
      'incidentType': _$IncidentTypeEnumMap[instance.incidentType],
      'incidentConfidence':
          _$IncidentConfidenceEnumMap[instance.incidentConfidence],
      'incidentDetectedAt': instance.incidentDetectedAt?.toIso8601String(),
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'timedOutAt': instance.timedOutAt?.toIso8601String(),
      'timeoutProcessedAt': instance.timeoutProcessedAt?.toIso8601String(),
      'escalationReadyAt': instance.escalationReadyAt?.toIso8601String(),
      'presentedAt': instance.presentedAt?.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
      'resolution': _$EscalationResolutionEnumMap[instance.resolution],
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'cancelReason': _$SafetyCheckCancelReasonEnumMap[instance.cancelReason],
      'escalationQueuedAt': instance.escalationQueuedAt?.toIso8601String(),
      'escalationSyncedAt': instance.escalationSyncedAt?.toIso8601String(),
    };

const _$SafetyCheckStatusEnumMap = {
  SafetyCheckStatus.pending: 'pending',
  SafetyCheckStatus.confirmedSafe: 'confirmedSafe',
  SafetyCheckStatus.timedOut: 'timedOut',
  SafetyCheckStatus.escalationReady: 'escalationReady',
  SafetyCheckStatus.cancelled: 'cancelled',
};

const _$IncidentTypeEnumMap = {
  IncidentType.suddenDeceleration: 'suddenDeceleration',
  IncidentType.prolongedStop: 'prolongedStop',
  IncidentType.trackingInterrupted: 'trackingInterrupted',
};

const _$IncidentConfidenceEnumMap = {
  IncidentConfidence.low: 'low',
  IncidentConfidence.medium: 'medium',
  IncidentConfidence.high: 'high',
};

const _$EscalationResolutionEnumMap = {
  EscalationResolution.userSafe: 'userSafe',
  EscalationResolution.journeyEnded: 'journeyEnded',
};

const _$SafetyCheckCancelReasonEnumMap = {
  SafetyCheckCancelReason.journeyEnded: 'journeyEnded',
  SafetyCheckCancelReason.signedOut: 'signedOut',
};
