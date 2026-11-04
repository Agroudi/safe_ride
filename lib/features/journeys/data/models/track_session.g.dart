// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrackSession _$TrackSessionFromJson(Map<String, dynamic> json) =>
    _TrackSession(
      journeyId: json['journeyId'] as String,
      uid: json['uid'] as String,
      recording: json['recording'] as bool,
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] == null
          ? null
          : DateTime.parse(json['stoppedAt'] as String),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      pointCount: (json['pointCount'] as num?)?.toInt() ?? 0,
      syncedCount: (json['syncedCount'] as num?)?.toInt() ?? 0,
      finalSynced: json['finalSynced'] as bool? ?? false,
      segment: (json['segment'] as num?)?.toInt() ?? 0,
      last: json['last'] == null
          ? null
          : TrackPoint.fromJson(json['last'] as Map<String, dynamic>),
      lastFixAt: json['lastFixAt'] == null
          ? null
          : DateTime.parse(json['lastFixAt'] as String),
    );

Map<String, dynamic> _$TrackSessionToJson(_TrackSession instance) =>
    <String, dynamic>{
      'journeyId': instance.journeyId,
      'uid': instance.uid,
      'recording': instance.recording,
      'startedAt': instance.startedAt.toIso8601String(),
      'stoppedAt': instance.stoppedAt?.toIso8601String(),
      'distanceMeters': instance.distanceMeters,
      'pointCount': instance.pointCount,
      'syncedCount': instance.syncedCount,
      'finalSynced': instance.finalSynced,
      'segment': instance.segment,
      'last': instance.last?.toJson(),
      'lastFixAt': instance.lastFixAt?.toIso8601String(),
    };
