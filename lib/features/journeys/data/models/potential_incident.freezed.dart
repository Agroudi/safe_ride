// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'potential_incident.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PotentialIncident {

 String get id; String get journeyId; String get uid; IncidentType get type; IncidentStatus get status; IncidentConfidence get confidence;/// When it was noticed (UTC).
 DateTime get detectedAt; DateTime get updatedAt;/// A short technical account of what the data showed (logs, not UI).
 String get reason;/// km/h before and after a sudden deceleration; at detection for a stop.
 double? get speedBeforeKmh; double? get speedAfterKmh;/// m/s², for a sudden deceleration.
 double? get deceleration;/// How long the stop or the interruption had lasted when noticed.
 int? get durationSeconds; double? get lat; double? get lng;/// The fix's accuracy (metres) and how old it was (seconds) when used.
 double? get accuracyMeters; double? get fixAgeSeconds; InterruptionCause? get interruption; IncidentResolution? get resolution; String? get supersededBy;
/// Create a copy of PotentialIncident
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PotentialIncidentCopyWith<PotentialIncident> get copyWith => _$PotentialIncidentCopyWithImpl<PotentialIncident>(this as PotentialIncident, _$identity);

  /// Serializes this PotentialIncident to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PotentialIncident&&(identical(other.id, id) || other.id == id)&&(identical(other.journeyId, journeyId) || other.journeyId == journeyId)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.detectedAt, detectedAt) || other.detectedAt == detectedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.speedBeforeKmh, speedBeforeKmh) || other.speedBeforeKmh == speedBeforeKmh)&&(identical(other.speedAfterKmh, speedAfterKmh) || other.speedAfterKmh == speedAfterKmh)&&(identical(other.deceleration, deceleration) || other.deceleration == deceleration)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.accuracyMeters, accuracyMeters) || other.accuracyMeters == accuracyMeters)&&(identical(other.fixAgeSeconds, fixAgeSeconds) || other.fixAgeSeconds == fixAgeSeconds)&&(identical(other.interruption, interruption) || other.interruption == interruption)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.supersededBy, supersededBy) || other.supersededBy == supersededBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,journeyId,uid,type,status,confidence,detectedAt,updatedAt,reason,speedBeforeKmh,speedAfterKmh,deceleration,durationSeconds,lat,lng,accuracyMeters,fixAgeSeconds,interruption,resolution,supersededBy]);

@override
String toString() {
  return 'PotentialIncident(id: $id, journeyId: $journeyId, uid: $uid, type: $type, status: $status, confidence: $confidence, detectedAt: $detectedAt, updatedAt: $updatedAt, reason: $reason, speedBeforeKmh: $speedBeforeKmh, speedAfterKmh: $speedAfterKmh, deceleration: $deceleration, durationSeconds: $durationSeconds, lat: $lat, lng: $lng, accuracyMeters: $accuracyMeters, fixAgeSeconds: $fixAgeSeconds, interruption: $interruption, resolution: $resolution, supersededBy: $supersededBy)';
}


}

/// @nodoc
abstract mixin class $PotentialIncidentCopyWith<$Res>  {
  factory $PotentialIncidentCopyWith(PotentialIncident value, $Res Function(PotentialIncident) _then) = _$PotentialIncidentCopyWithImpl;
@useResult
$Res call({
 String id, String journeyId, String uid, IncidentType type, IncidentStatus status, IncidentConfidence confidence, DateTime detectedAt, DateTime updatedAt, String reason, double? speedBeforeKmh, double? speedAfterKmh, double? deceleration, int? durationSeconds, double? lat, double? lng, double? accuracyMeters, double? fixAgeSeconds, InterruptionCause? interruption, IncidentResolution? resolution, String? supersededBy
});




}
/// @nodoc
class _$PotentialIncidentCopyWithImpl<$Res>
    implements $PotentialIncidentCopyWith<$Res> {
  _$PotentialIncidentCopyWithImpl(this._self, this._then);

  final PotentialIncident _self;
  final $Res Function(PotentialIncident) _then;

/// Create a copy of PotentialIncident
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? journeyId = null,Object? uid = null,Object? type = null,Object? status = null,Object? confidence = null,Object? detectedAt = null,Object? updatedAt = null,Object? reason = null,Object? speedBeforeKmh = freezed,Object? speedAfterKmh = freezed,Object? deceleration = freezed,Object? durationSeconds = freezed,Object? lat = freezed,Object? lng = freezed,Object? accuracyMeters = freezed,Object? fixAgeSeconds = freezed,Object? interruption = freezed,Object? resolution = freezed,Object? supersededBy = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,journeyId: null == journeyId ? _self.journeyId : journeyId // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as IncidentType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as IncidentStatus,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as IncidentConfidence,detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,speedBeforeKmh: freezed == speedBeforeKmh ? _self.speedBeforeKmh : speedBeforeKmh // ignore: cast_nullable_to_non_nullable
as double?,speedAfterKmh: freezed == speedAfterKmh ? _self.speedAfterKmh : speedAfterKmh // ignore: cast_nullable_to_non_nullable
as double?,deceleration: freezed == deceleration ? _self.deceleration : deceleration // ignore: cast_nullable_to_non_nullable
as double?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,accuracyMeters: freezed == accuracyMeters ? _self.accuracyMeters : accuracyMeters // ignore: cast_nullable_to_non_nullable
as double?,fixAgeSeconds: freezed == fixAgeSeconds ? _self.fixAgeSeconds : fixAgeSeconds // ignore: cast_nullable_to_non_nullable
as double?,interruption: freezed == interruption ? _self.interruption : interruption // ignore: cast_nullable_to_non_nullable
as InterruptionCause?,resolution: freezed == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as IncidentResolution?,supersededBy: freezed == supersededBy ? _self.supersededBy : supersededBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PotentialIncident].
extension PotentialIncidentPatterns on PotentialIncident {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PotentialIncident value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PotentialIncident() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PotentialIncident value)  $default,){
final _that = this;
switch (_that) {
case _PotentialIncident():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PotentialIncident value)?  $default,){
final _that = this;
switch (_that) {
case _PotentialIncident() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String journeyId,  String uid,  IncidentType type,  IncidentStatus status,  IncidentConfidence confidence,  DateTime detectedAt,  DateTime updatedAt,  String reason,  double? speedBeforeKmh,  double? speedAfterKmh,  double? deceleration,  int? durationSeconds,  double? lat,  double? lng,  double? accuracyMeters,  double? fixAgeSeconds,  InterruptionCause? interruption,  IncidentResolution? resolution,  String? supersededBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PotentialIncident() when $default != null:
return $default(_that.id,_that.journeyId,_that.uid,_that.type,_that.status,_that.confidence,_that.detectedAt,_that.updatedAt,_that.reason,_that.speedBeforeKmh,_that.speedAfterKmh,_that.deceleration,_that.durationSeconds,_that.lat,_that.lng,_that.accuracyMeters,_that.fixAgeSeconds,_that.interruption,_that.resolution,_that.supersededBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String journeyId,  String uid,  IncidentType type,  IncidentStatus status,  IncidentConfidence confidence,  DateTime detectedAt,  DateTime updatedAt,  String reason,  double? speedBeforeKmh,  double? speedAfterKmh,  double? deceleration,  int? durationSeconds,  double? lat,  double? lng,  double? accuracyMeters,  double? fixAgeSeconds,  InterruptionCause? interruption,  IncidentResolution? resolution,  String? supersededBy)  $default,) {final _that = this;
switch (_that) {
case _PotentialIncident():
return $default(_that.id,_that.journeyId,_that.uid,_that.type,_that.status,_that.confidence,_that.detectedAt,_that.updatedAt,_that.reason,_that.speedBeforeKmh,_that.speedAfterKmh,_that.deceleration,_that.durationSeconds,_that.lat,_that.lng,_that.accuracyMeters,_that.fixAgeSeconds,_that.interruption,_that.resolution,_that.supersededBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String journeyId,  String uid,  IncidentType type,  IncidentStatus status,  IncidentConfidence confidence,  DateTime detectedAt,  DateTime updatedAt,  String reason,  double? speedBeforeKmh,  double? speedAfterKmh,  double? deceleration,  int? durationSeconds,  double? lat,  double? lng,  double? accuracyMeters,  double? fixAgeSeconds,  InterruptionCause? interruption,  IncidentResolution? resolution,  String? supersededBy)?  $default,) {final _that = this;
switch (_that) {
case _PotentialIncident() when $default != null:
return $default(_that.id,_that.journeyId,_that.uid,_that.type,_that.status,_that.confidence,_that.detectedAt,_that.updatedAt,_that.reason,_that.speedBeforeKmh,_that.speedAfterKmh,_that.deceleration,_that.durationSeconds,_that.lat,_that.lng,_that.accuracyMeters,_that.fixAgeSeconds,_that.interruption,_that.resolution,_that.supersededBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PotentialIncident implements PotentialIncident {
  const _PotentialIncident({required this.id, required this.journeyId, required this.uid, required this.type, required this.status, required this.confidence, required this.detectedAt, required this.updatedAt, required this.reason, this.speedBeforeKmh, this.speedAfterKmh, this.deceleration, this.durationSeconds, this.lat, this.lng, this.accuracyMeters, this.fixAgeSeconds, this.interruption, this.resolution, this.supersededBy});
  factory _PotentialIncident.fromJson(Map<String, dynamic> json) => _$PotentialIncidentFromJson(json);

@override final  String id;
@override final  String journeyId;
@override final  String uid;
@override final  IncidentType type;
@override final  IncidentStatus status;
@override final  IncidentConfidence confidence;
/// When it was noticed (UTC).
@override final  DateTime detectedAt;
@override final  DateTime updatedAt;
/// A short technical account of what the data showed (logs, not UI).
@override final  String reason;
/// km/h before and after a sudden deceleration; at detection for a stop.
@override final  double? speedBeforeKmh;
@override final  double? speedAfterKmh;
/// m/s², for a sudden deceleration.
@override final  double? deceleration;
/// How long the stop or the interruption had lasted when noticed.
@override final  int? durationSeconds;
@override final  double? lat;
@override final  double? lng;
/// The fix's accuracy (metres) and how old it was (seconds) when used.
@override final  double? accuracyMeters;
@override final  double? fixAgeSeconds;
@override final  InterruptionCause? interruption;
@override final  IncidentResolution? resolution;
@override final  String? supersededBy;

/// Create a copy of PotentialIncident
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PotentialIncidentCopyWith<_PotentialIncident> get copyWith => __$PotentialIncidentCopyWithImpl<_PotentialIncident>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PotentialIncidentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PotentialIncident&&(identical(other.id, id) || other.id == id)&&(identical(other.journeyId, journeyId) || other.journeyId == journeyId)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.detectedAt, detectedAt) || other.detectedAt == detectedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.speedBeforeKmh, speedBeforeKmh) || other.speedBeforeKmh == speedBeforeKmh)&&(identical(other.speedAfterKmh, speedAfterKmh) || other.speedAfterKmh == speedAfterKmh)&&(identical(other.deceleration, deceleration) || other.deceleration == deceleration)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.accuracyMeters, accuracyMeters) || other.accuracyMeters == accuracyMeters)&&(identical(other.fixAgeSeconds, fixAgeSeconds) || other.fixAgeSeconds == fixAgeSeconds)&&(identical(other.interruption, interruption) || other.interruption == interruption)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.supersededBy, supersededBy) || other.supersededBy == supersededBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,journeyId,uid,type,status,confidence,detectedAt,updatedAt,reason,speedBeforeKmh,speedAfterKmh,deceleration,durationSeconds,lat,lng,accuracyMeters,fixAgeSeconds,interruption,resolution,supersededBy]);

@override
String toString() {
  return 'PotentialIncident(id: $id, journeyId: $journeyId, uid: $uid, type: $type, status: $status, confidence: $confidence, detectedAt: $detectedAt, updatedAt: $updatedAt, reason: $reason, speedBeforeKmh: $speedBeforeKmh, speedAfterKmh: $speedAfterKmh, deceleration: $deceleration, durationSeconds: $durationSeconds, lat: $lat, lng: $lng, accuracyMeters: $accuracyMeters, fixAgeSeconds: $fixAgeSeconds, interruption: $interruption, resolution: $resolution, supersededBy: $supersededBy)';
}


}

/// @nodoc
abstract mixin class _$PotentialIncidentCopyWith<$Res> implements $PotentialIncidentCopyWith<$Res> {
  factory _$PotentialIncidentCopyWith(_PotentialIncident value, $Res Function(_PotentialIncident) _then) = __$PotentialIncidentCopyWithImpl;
@override @useResult
$Res call({
 String id, String journeyId, String uid, IncidentType type, IncidentStatus status, IncidentConfidence confidence, DateTime detectedAt, DateTime updatedAt, String reason, double? speedBeforeKmh, double? speedAfterKmh, double? deceleration, int? durationSeconds, double? lat, double? lng, double? accuracyMeters, double? fixAgeSeconds, InterruptionCause? interruption, IncidentResolution? resolution, String? supersededBy
});




}
/// @nodoc
class __$PotentialIncidentCopyWithImpl<$Res>
    implements _$PotentialIncidentCopyWith<$Res> {
  __$PotentialIncidentCopyWithImpl(this._self, this._then);

  final _PotentialIncident _self;
  final $Res Function(_PotentialIncident) _then;

/// Create a copy of PotentialIncident
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? journeyId = null,Object? uid = null,Object? type = null,Object? status = null,Object? confidence = null,Object? detectedAt = null,Object? updatedAt = null,Object? reason = null,Object? speedBeforeKmh = freezed,Object? speedAfterKmh = freezed,Object? deceleration = freezed,Object? durationSeconds = freezed,Object? lat = freezed,Object? lng = freezed,Object? accuracyMeters = freezed,Object? fixAgeSeconds = freezed,Object? interruption = freezed,Object? resolution = freezed,Object? supersededBy = freezed,}) {
  return _then(_PotentialIncident(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,journeyId: null == journeyId ? _self.journeyId : journeyId // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as IncidentType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as IncidentStatus,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as IncidentConfidence,detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,speedBeforeKmh: freezed == speedBeforeKmh ? _self.speedBeforeKmh : speedBeforeKmh // ignore: cast_nullable_to_non_nullable
as double?,speedAfterKmh: freezed == speedAfterKmh ? _self.speedAfterKmh : speedAfterKmh // ignore: cast_nullable_to_non_nullable
as double?,deceleration: freezed == deceleration ? _self.deceleration : deceleration // ignore: cast_nullable_to_non_nullable
as double?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,accuracyMeters: freezed == accuracyMeters ? _self.accuracyMeters : accuracyMeters // ignore: cast_nullable_to_non_nullable
as double?,fixAgeSeconds: freezed == fixAgeSeconds ? _self.fixAgeSeconds : fixAgeSeconds // ignore: cast_nullable_to_non_nullable
as double?,interruption: freezed == interruption ? _self.interruption : interruption // ignore: cast_nullable_to_non_nullable
as InterruptionCause?,resolution: freezed == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as IncidentResolution?,supersededBy: freezed == supersededBy ? _self.supersededBy : supersededBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
