// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  fullName: json['fullName'] as String,
  email: json['email'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  phone: json['phone'] as String?,
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'email': instance.email,
      'createdAt': instance.createdAt.toIso8601String(),
      'phone': instance.phone,
    };
