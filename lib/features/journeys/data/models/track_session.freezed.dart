// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrackSession {

 String get journeyId; String get uid;/// True while the journey is in progress and should be recorded —
/// including while the recording is interrupted (no permission, the app
/// closed), so it resumes; false once the journey ended.
 bool get recording;/// When the first recording began (UTC).
 DateTime get startedAt;/// The journey ended and the recording with it (UTC).
 DateTime? get stoppedAt;/// Metres between consecutive trusted points of the same segment.
 double get distanceMeters;/// How many points are stored; and how many of them the account has.
 int get pointCount; int get syncedCount;/// The account has the final summary (recording over).
 bool get finalSynced;/// The current segment (see `TrackPoint.segment`).
 int get segment;/// The last trusted point, to measure the next one from.
 TrackPoint? get last;/// The last fix of any quality (UTC): a gap in fixes starts a segment.
 DateTime? get lastFixAt;
/// Create a copy of TrackSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackSessionCopyWith<TrackSession> get copyWith => _$TrackSessionCopyWithImpl<TrackSession>(this as TrackSession, _$identity);

  /// Serializes this TrackSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackSession&&(identical(other.journeyId, journeyId) || other.journeyId == journeyId)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.recording, recording) || other.recording == recording)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.stoppedAt, stoppedAt) || other.stoppedAt == stoppedAt)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.pointCount, pointCount) || other.pointCount == pointCount)&&(identical(other.syncedCount, syncedCount) || other.syncedCount == syncedCount)&&(identical(other.finalSynced, finalSynced) || other.finalSynced == finalSynced)&&(identical(other.segment, segment) || other.segment == segment)&&(identical(other.last, last) || other.last == last)&&(identical(other.lastFixAt, lastFixAt) || other.lastFixAt == lastFixAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,journeyId,uid,recording,startedAt,stoppedAt,distanceMeters,pointCount,syncedCount,finalSynced,segment,last,lastFixAt);

@override
String toString() {
  return 'TrackSession(journeyId: $journeyId, uid: $uid, recording: $recording, startedAt: $startedAt, stoppedAt: $stoppedAt, distanceMeters: $distanceMeters, pointCount: $pointCount, syncedCount: $syncedCount, finalSynced: $finalSynced, segment: $segment, last: $last, lastFixAt: $lastFixAt)';
}


}

/// @nodoc
abstract mixin class $TrackSessionCopyWith<$Res>  {
  factory $TrackSessionCopyWith(TrackSession value, $Res Function(TrackSession) _then) = _$TrackSessionCopyWithImpl;
@useResult
$Res call({
 String journeyId, String uid, bool recording, DateTime startedAt, DateTime? stoppedAt, double distanceMeters, int pointCount, int syncedCount, bool finalSynced, int segment, TrackPoint? last, DateTime? lastFixAt
});


$TrackPointCopyWith<$Res>? get last;

}
/// @nodoc
class _$TrackSessionCopyWithImpl<$Res>
    implements $TrackSessionCopyWith<$Res> {
  _$TrackSessionCopyWithImpl(this._self, this._then);

  final TrackSession _self;
  final $Res Function(TrackSession) _then;

/// Create a copy of TrackSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? journeyId = null,Object? uid = null,Object? recording = null,Object? startedAt = null,Object? stoppedAt = freezed,Object? distanceMeters = null,Object? pointCount = null,Object? syncedCount = null,Object? finalSynced = null,Object? segment = null,Object? last = freezed,Object? lastFixAt = freezed,}) {
  return _then(_self.copyWith(
journeyId: null == journeyId ? _self.journeyId : journeyId // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,recording: null == recording ? _self.recording : recording // ignore: cast_nullable_to_non_nullable
as bool,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,stoppedAt: freezed == stoppedAt ? _self.stoppedAt : stoppedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double,pointCount: null == pointCount ? _self.pointCount : pointCount // ignore: cast_nullable_to_non_nullable
as int,syncedCount: null == syncedCount ? _self.syncedCount : syncedCount // ignore: cast_nullable_to_non_nullable
as int,finalSynced: null == finalSynced ? _self.finalSynced : finalSynced // ignore: cast_nullable_to_non_nullable
as bool,segment: null == segment ? _self.segment : segment // ignore: cast_nullable_to_non_nullable
as int,last: freezed == last ? _self.last : last // ignore: cast_nullable_to_non_nullable
as TrackPoint?,lastFixAt: freezed == lastFixAt ? _self.lastFixAt : lastFixAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of TrackSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrackPointCopyWith<$Res>? get last {
    if (_self.last == null) {
    return null;
  }

  return $TrackPointCopyWith<$Res>(_self.last!, (value) {
    return _then(_self.copyWith(last: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrackSession].
extension TrackSessionPatterns on TrackSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackSession value)  $default,){
final _that = this;
switch (_that) {
case _TrackSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackSession value)?  $default,){
final _that = this;
switch (_that) {
case _TrackSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String journeyId,  String uid,  bool recording,  DateTime startedAt,  DateTime? stoppedAt,  double distanceMeters,  int pointCount,  int syncedCount,  bool finalSynced,  int segment,  TrackPoint? last,  DateTime? lastFixAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackSession() when $default != null:
return $default(_that.journeyId,_that.uid,_that.recording,_that.startedAt,_that.stoppedAt,_that.distanceMeters,_that.pointCount,_that.syncedCount,_that.finalSynced,_that.segment,_that.last,_that.lastFixAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String journeyId,  String uid,  bool recording,  DateTime startedAt,  DateTime? stoppedAt,  double distanceMeters,  int pointCount,  int syncedCount,  bool finalSynced,  int segment,  TrackPoint? last,  DateTime? lastFixAt)  $default,) {final _that = this;
switch (_that) {
case _TrackSession():
return $default(_that.journeyId,_that.uid,_that.recording,_that.startedAt,_that.stoppedAt,_that.distanceMeters,_that.pointCount,_that.syncedCount,_that.finalSynced,_that.segment,_that.last,_that.lastFixAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String journeyId,  String uid,  bool recording,  DateTime startedAt,  DateTime? stoppedAt,  double distanceMeters,  int pointCount,  int syncedCount,  bool finalSynced,  int segment,  TrackPoint? last,  DateTime? lastFixAt)?  $default,) {final _that = this;
switch (_that) {
case _TrackSession() when $default != null:
return $default(_that.journeyId,_that.uid,_that.recording,_that.startedAt,_that.stoppedAt,_that.distanceMeters,_that.pointCount,_that.syncedCount,_that.finalSynced,_that.segment,_that.last,_that.lastFixAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackSession extends TrackSession {
  const _TrackSession({required this.journeyId, required this.uid, required this.recording, required this.startedAt, this.stoppedAt, this.distanceMeters = 0, this.pointCount = 0, this.syncedCount = 0, this.finalSynced = false, this.segment = 0, this.last, this.lastFixAt}): super._();
  factory _TrackSession.fromJson(Map<String, dynamic> json) => _$TrackSessionFromJson(json);

@override final  String journeyId;
@override final  String uid;
/// True while the journey is in progress and should be recorded —
/// including while the recording is interrupted (no permission, the app
/// closed), so it resumes; false once the journey ended.
@override final  bool recording;
/// When the first recording began (UTC).
@override final  DateTime startedAt;
/// The journey ended and the recording with it (UTC).
@override final  DateTime? stoppedAt;
/// Metres between consecutive trusted points of the same segment.
@override@JsonKey() final  double distanceMeters;
/// How many points are stored; and how many of them the account has.
@override@JsonKey() final  int pointCount;
@override@JsonKey() final  int syncedCount;
/// The account has the final summary (recording over).
@override@JsonKey() final  bool finalSynced;
/// The current segment (see `TrackPoint.segment`).
@override@JsonKey() final  int segment;
/// The last trusted point, to measure the next one from.
@override final  TrackPoint? last;
/// The last fix of any quality (UTC): a gap in fixes starts a segment.
@override final  DateTime? lastFixAt;

/// Create a copy of TrackSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackSessionCopyWith<_TrackSession> get copyWith => __$TrackSessionCopyWithImpl<_TrackSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackSession&&(identical(other.journeyId, journeyId) || other.journeyId == journeyId)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.recording, recording) || other.recording == recording)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.stoppedAt, stoppedAt) || other.stoppedAt == stoppedAt)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.pointCount, pointCount) || other.pointCount == pointCount)&&(identical(other.syncedCount, syncedCount) || other.syncedCount == syncedCount)&&(identical(other.finalSynced, finalSynced) || other.finalSynced == finalSynced)&&(identical(other.segment, segment) || other.segment == segment)&&(identical(other.last, last) || other.last == last)&&(identical(other.lastFixAt, lastFixAt) || other.lastFixAt == lastFixAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,journeyId,uid,recording,startedAt,stoppedAt,distanceMeters,pointCount,syncedCount,finalSynced,segment,last,lastFixAt);

@override
String toString() {
  return 'TrackSession(journeyId: $journeyId, uid: $uid, recording: $recording, startedAt: $startedAt, stoppedAt: $stoppedAt, distanceMeters: $distanceMeters, pointCount: $pointCount, syncedCount: $syncedCount, finalSynced: $finalSynced, segment: $segment, last: $last, lastFixAt: $lastFixAt)';
}


}

/// @nodoc
abstract mixin class _$TrackSessionCopyWith<$Res> implements $TrackSessionCopyWith<$Res> {
  factory _$TrackSessionCopyWith(_TrackSession value, $Res Function(_TrackSession) _then) = __$TrackSessionCopyWithImpl;
@override @useResult
$Res call({
 String journeyId, String uid, bool recording, DateTime startedAt, DateTime? stoppedAt, double distanceMeters, int pointCount, int syncedCount, bool finalSynced, int segment, TrackPoint? last, DateTime? lastFixAt
});


@override $TrackPointCopyWith<$Res>? get last;

}
/// @nodoc
class __$TrackSessionCopyWithImpl<$Res>
    implements _$TrackSessionCopyWith<$Res> {
  __$TrackSessionCopyWithImpl(this._self, this._then);

  final _TrackSession _self;
  final $Res Function(_TrackSession) _then;

/// Create a copy of TrackSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? journeyId = null,Object? uid = null,Object? recording = null,Object? startedAt = null,Object? stoppedAt = freezed,Object? distanceMeters = null,Object? pointCount = null,Object? syncedCount = null,Object? finalSynced = null,Object? segment = null,Object? last = freezed,Object? lastFixAt = freezed,}) {
  return _then(_TrackSession(
journeyId: null == journeyId ? _self.journeyId : journeyId // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,recording: null == recording ? _self.recording : recording // ignore: cast_nullable_to_non_nullable
as bool,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,stoppedAt: freezed == stoppedAt ? _self.stoppedAt : stoppedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double,pointCount: null == pointCount ? _self.pointCount : pointCount // ignore: cast_nullable_to_non_nullable
as int,syncedCount: null == syncedCount ? _self.syncedCount : syncedCount // ignore: cast_nullable_to_non_nullable
as int,finalSynced: null == finalSynced ? _self.finalSynced : finalSynced // ignore: cast_nullable_to_non_nullable
as bool,segment: null == segment ? _self.segment : segment // ignore: cast_nullable_to_non_nullable
as int,last: freezed == last ? _self.last : last // ignore: cast_nullable_to_non_nullable
as TrackPoint?,lastFixAt: freezed == lastFixAt ? _self.lastFixAt : lastFixAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of TrackSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrackPointCopyWith<$Res>? get last {
    if (_self.last == null) {
    return null;
  }

  return $TrackPointCopyWith<$Res>(_self.last!, (value) {
    return _then(_self.copyWith(last: value));
  });
}
}

// dart format on
