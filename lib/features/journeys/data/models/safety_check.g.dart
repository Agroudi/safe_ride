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
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'timedOutAt': instance.timedOutAt?.toIso8601String(),
      'timeoutProcessedAt': instance.timeoutProcessedAt?.toIso8601String(),
      'escalationReadyAt': instance.escalationReadyAt?.toIso8601String(),
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

const _$SafetyCheckCancelReasonEnumMap = {
  SafetyCheckCancelReason.journeyEnded: 'journeyEnded',
  SafetyCheckCancelReason.signedOut: 'signedOut',
};
