// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'escalation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Escalation _$EscalationFromJson(Map<String, dynamic> json) => _Escalation(
  status: $enumDecode(_$EscalationStatusEnumMap, json['status']),
  reason: json['reason'] as String?,
  recipients: (json['recipients'] as num?)?.toInt() ?? 0,
  accepted: (json['accepted'] as num?)?.toInt() ?? 0,
  failed: (json['failed'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$EscalationToJson(_Escalation instance) =>
    <String, dynamic>{
      'status': _$EscalationStatusEnumMap[instance.status]!,
      'reason': instance.reason,
      'recipients': instance.recipients,
      'accepted': instance.accepted,
      'failed': instance.failed,
    };

const _$EscalationStatusEnumMap = {
  EscalationStatus.dispatching: 'dispatching',
  EscalationStatus.retrying: 'retrying',
  EscalationStatus.completed: 'completed',
  EscalationStatus.failed: 'failed',
  EscalationStatus.noRecipients: 'noRecipients',
  EscalationStatus.rejected: 'rejected',
};
