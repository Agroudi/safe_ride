// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConnectionPermissions _$ConnectionPermissionsFromJson(
  Map<String, dynamic> json,
) => _ConnectionPermissions(
  safetyAlerts: json['safetyAlerts'] as bool? ?? false,
);

Map<String, dynamic> _$ConnectionPermissionsToJson(
  _ConnectionPermissions instance,
) => <String, dynamic>{'safetyAlerts': instance.safetyAlerts};

_ConnectionModel _$ConnectionModelFromJson(Map<String, dynamic> json) =>
    _ConnectionModel(
      ownerUid: json['ownerUid'] as String,
      contactUid: json['contactUid'] as String,
      contactName: json['contactName'] as String,
      status: $enumDecode(_$ConnectionStatusEnumMap, json['status']),
      inviteId: json['inviteId'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      acceptedAt: const TimestampConverter().fromJson(json['acceptedAt']),
      permissions: json['permissions'] == null
          ? const ConnectionPermissions()
          : ConnectionPermissions.fromJson(
              json['permissions'] as Map<String, dynamic>,
            ),
      nickname: json['nickname'] as String?,
      revokedAt: const NullableTimestampConverter().fromJson(json['revokedAt']),
      revokedBy: json['revokedBy'] as String?,
    );

Map<String, dynamic> _$ConnectionModelToJson(
  _ConnectionModel instance,
) => <String, dynamic>{
  'ownerUid': instance.ownerUid,
  'contactUid': instance.contactUid,
  'contactName': instance.contactName,
  'status': _$ConnectionStatusEnumMap[instance.status]!,
  'inviteId': instance.inviteId,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'acceptedAt': const TimestampConverter().toJson(instance.acceptedAt),
  'permissions': instance.permissions.toJson(),
  'nickname': instance.nickname,
  'revokedAt': const NullableTimestampConverter().toJson(instance.revokedAt),
  'revokedBy': instance.revokedBy,
};

const _$ConnectionStatusEnumMap = {
  ConnectionStatus.pending: 'pending',
  ConnectionStatus.accepted: 'accepted',
  ConnectionStatus.revoked: 'revoked',
  ConnectionStatus.expired: 'expired',
};
