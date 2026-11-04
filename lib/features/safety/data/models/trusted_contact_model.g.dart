// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trusted_contact_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrustedContactModel _$TrustedContactModelFromJson(Map<String, dynamic> json) =>
    _TrustedContactModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      relationship: json['relationship'] as String?,
    );

Map<String, dynamic> _$TrustedContactModelToJson(
  _TrustedContactModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'relationship': instance.relationship,
};
