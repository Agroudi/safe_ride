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
      createdAt: DateTime.parse(json['createdAt'] as String),
      relationship: json['relationship'] as String?,
    );

Map<String, dynamic> _$TrustedContactModelToJson(
  _TrustedContactModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'createdAt': instance.createdAt.toIso8601String(),
  'relationship': instance.relationship,
};
