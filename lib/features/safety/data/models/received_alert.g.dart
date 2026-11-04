// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'received_alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReceivedAlert _$ReceivedAlertFromJson(Map<String, dynamic> json) =>
    _ReceivedAlert(
      id: json['id'] as String,
      fromName: json['fromName'] as String,
      type: json['type'] as String,
      eventAt: const TimestampConverter().fromJson(json['eventAt']),
      fromPhone: json['fromPhone'] as String?,
    );

Map<String, dynamic> _$ReceivedAlertToJson(_ReceivedAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromName': instance.fromName,
      'type': instance.type,
      'eventAt': const TimestampConverter().toJson(instance.eventAt),
      'fromPhone': instance.fromPhone,
    };
