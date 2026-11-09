// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_invite_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConnectionInviteModel _$ConnectionInviteModelFromJson(
  Map<String, dynamic> json,
) => _ConnectionInviteModel(
  token: json['token'] as String,
  inviterUid: json['inviterUid'] as String,
  inviterName: json['inviterName'] as String,
  status: $enumDecode(_$ConnectionStatusEnumMap, json['status']),
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  expiresAt: const TimestampConverter().fromJson(json['expiresAt']),
  acceptedBy: json['acceptedBy'] as String?,
  acceptedAt: const NullableTimestampConverter().fromJson(json['acceptedAt']),
);

Map<String, dynamic> _$ConnectionInviteModelToJson(
  _ConnectionInviteModel instance,
) => <String, dynamic>{
  'token': instance.token,
  'inviterUid': instance.inviterUid,
  'inviterName': instance.inviterName,
  'status': _$ConnectionStatusEnumMap[instance.status]!,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'expiresAt': const TimestampConverter().toJson(instance.expiresAt),
  'acceptedBy': instance.acceptedBy,
  'acceptedAt': const NullableTimestampConverter().toJson(instance.acceptedAt),
};

const _$ConnectionStatusEnumMap = {
  ConnectionStatus.pending: 'pending',
  ConnectionStatus.accepted: 'accepted',
  ConnectionStatus.revoked: 'revoked',
  ConnectionStatus.expired: 'expired',
};
