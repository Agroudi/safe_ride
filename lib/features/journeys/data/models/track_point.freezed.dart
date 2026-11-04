// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_point.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrackPoint {

 double get lat; double get lng;/// When the phone took the fix (UTC).
 DateTime get at;/// Horizontal accuracy in metres.
 double get accuracy;/// Metres per second, only when the phone's reading was trustworthy.
 double? get speed;/// Which unbroken stretch of the route this point belongs to: a new
/// segment begins after the recording stopped or lost every signal for a
/// while. No distance is counted across segments.
 int get segment;
/// Create a copy of TrackPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackPointCopyWith<TrackPoint> get copyWith => _$TrackPointCopyWithImpl<TrackPoint>(this as TrackPoint, _$identity);

  /// Serializes this TrackPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackPoint&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.at, at) || other.at == at)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.segment, segment) || other.segment == segment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,at,accuracy,speed,segment);

@override
String toString() {
  return 'TrackPoint(lat: $lat, lng: $lng, at: $at, accuracy: $accuracy, speed: $speed, segment: $segment)';
}


}

/// @nodoc
abstract mixin class $TrackPointCopyWith<$Res>  {
  factory $TrackPointCopyWith(TrackPoint value, $Res Function(TrackPoint) _then) = _$TrackPointCopyWithImpl;
@useResult
$Res call({
 double lat, double lng, DateTime at, double accuracy, double? speed, int segment
});




}
/// @nodoc
class _$TrackPointCopyWithImpl<$Res>
    implements $TrackPointCopyWith<$Res> {
  _$TrackPointCopyWithImpl(this._self, this._then);

  final TrackPoint _self;
  final $Res Function(TrackPoint) _then;

/// Create a copy of TrackPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,Object? at = null,Object? accuracy = null,Object? speed = freezed,Object? segment = null,}) {
  return _then(_self.copyWith(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,accuracy: null == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,segment: null == segment ? _self.segment : segment // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackPoint].
extension TrackPointPatterns on TrackPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackPoint value)  $default,){
final _that = this;
switch (_that) {
case _TrackPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackPoint value)?  $default,){
final _that = this;
switch (_that) {
case _TrackPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng,  DateTime at,  double accuracy,  double? speed,  int segment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackPoint() when $default != null:
return $default(_that.lat,_that.lng,_that.at,_that.accuracy,_that.speed,_that.segment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng,  DateTime at,  double accuracy,  double? speed,  int segment)  $default,) {final _that = this;
switch (_that) {
case _TrackPoint():
return $default(_that.lat,_that.lng,_that.at,_that.accuracy,_that.speed,_that.segment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng,  DateTime at,  double accuracy,  double? speed,  int segment)?  $default,) {final _that = this;
switch (_that) {
case _TrackPoint() when $default != null:
return $default(_that.lat,_that.lng,_that.at,_that.accuracy,_that.speed,_that.segment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackPoint implements TrackPoint {
  const _TrackPoint({required this.lat, required this.lng, required this.at, required this.accuracy, this.speed, this.segment = 0});
  factory _TrackPoint.fromJson(Map<String, dynamic> json) => _$TrackPointFromJson(json);

@override final  double lat;
@override final  double lng;
/// When the phone took the fix (UTC).
@override final  DateTime at;
/// Horizontal accuracy in metres.
@override final  double accuracy;
/// Metres per second, only when the phone's reading was trustworthy.
@override final  double? speed;
/// Which unbroken stretch of the route this point belongs to: a new
/// segment begins after the recording stopped or lost every signal for a
/// while. No distance is counted across segments.
@override@JsonKey() final  int segment;

/// Create a copy of TrackPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackPointCopyWith<_TrackPoint> get copyWith => __$TrackPointCopyWithImpl<_TrackPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackPoint&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.at, at) || other.at == at)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.segment, segment) || other.segment == segment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,at,accuracy,speed,segment);

@override
String toString() {
  return 'TrackPoint(lat: $lat, lng: $lng, at: $at, accuracy: $accuracy, speed: $speed, segment: $segment)';
}


}

/// @nodoc
abstract mixin class _$TrackPointCopyWith<$Res> implements $TrackPointCopyWith<$Res> {
  factory _$TrackPointCopyWith(_TrackPoint value, $Res Function(_TrackPoint) _then) = __$TrackPointCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng, DateTime at, double accuracy, double? speed, int segment
});




}
/// @nodoc
class __$TrackPointCopyWithImpl<$Res>
    implements _$TrackPointCopyWith<$Res> {
  __$TrackPointCopyWithImpl(this._self, this._then);

  final _TrackPoint _self;
  final $Res Function(_TrackPoint) _then;

/// Create a copy of TrackPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,Object? at = null,Object? accuracy = null,Object? speed = freezed,Object? segment = null,}) {
  return _then(_TrackPoint(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,accuracy: null == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,segment: null == segment ? _self.segment : segment // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
