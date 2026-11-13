// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiMessage _$AiMessageFromJson(Map<String, dynamic> json) => _AiMessage(
  id: json['id'] as String,
  role: $enumDecode(_$AiRoleEnumMap, json['role']),
  text: json['text'] as String,
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$AiMessageToJson(_AiMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$AiRoleEnumMap[instance.role]!,
      'text': instance.text,
      'at': instance.at.toIso8601String(),
    };

const _$AiRoleEnumMap = {AiRole.user: 'user', AiRole.assistant: 'assistant'};
