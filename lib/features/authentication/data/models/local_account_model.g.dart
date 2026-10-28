// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_account_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LocalAccountModel _$LocalAccountModelFromJson(Map<String, dynamic> json) =>
    _LocalAccountModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      salt: json['salt'] as String,
      hash: json['hash'] as String,
      iterations: (json['iterations'] as num).toInt(),
    );

Map<String, dynamic> _$LocalAccountModelToJson(_LocalAccountModel instance) =>
    <String, dynamic>{
      'user': instance.user.toJson(),
      'salt': instance.salt,
      'hash': instance.hash,
      'iterations': instance.iterations,
    };
