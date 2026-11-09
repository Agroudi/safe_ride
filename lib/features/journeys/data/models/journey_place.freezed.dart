// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journey_place.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JourneyPlace {

 String get name; double get lat; double get lng;/// The provider's fuller description, when it gave one.
 String? get address;/// The provider's id for the place, when it has one.
 String? get placeId;
/// Create a copy of JourneyPlace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JourneyPlaceCopyWith<JourneyPlace> get copyWith => _$JourneyPlaceCopyWithImpl<JourneyPlace>(this as JourneyPlace, _$identity);

  /// Serializes this JourneyPlace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyPlace&&(identical(other.name, name) || other.name == name)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.address, address) || other.address == address)&&(identical(other.placeId, placeId) || other.placeId == placeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,lat,lng,address,placeId);

@override
String toString() {
  return 'JourneyPlace(name: $name, lat: $lat, lng: $lng, address: $address, placeId: $placeId)';
}


}

/// @nodoc
abstract mixin class $JourneyPlaceCopyWith<$Res>  {
  factory $JourneyPlaceCopyWith(JourneyPlace value, $Res Function(JourneyPlace) _then) = _$JourneyPlaceCopyWithImpl;
@useResult
$Res call({
 String name, double lat, double lng, String? address, String? placeId
});




}
/// @nodoc
class _$JourneyPlaceCopyWithImpl<$Res>
    implements $JourneyPlaceCopyWith<$Res> {
  _$JourneyPlaceCopyWithImpl(this._self, this._then);

  final JourneyPlace _self;
  final $Res Function(JourneyPlace) _then;

/// Create a copy of JourneyPlace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? lat = null,Object? lng = null,Object? address = freezed,Object? placeId = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,placeId: freezed == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [JourneyPlace].
extension JourneyPlacePatterns on JourneyPlace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JourneyPlace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JourneyPlace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JourneyPlace value)  $default,){
final _that = this;
switch (_that) {
case _JourneyPlace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JourneyPlace value)?  $default,){
final _that = this;
switch (_that) {
case _JourneyPlace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  double lat,  double lng,  String? address,  String? placeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JourneyPlace() when $default != null:
return $default(_that.name,_that.lat,_that.lng,_that.address,_that.placeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  double lat,  double lng,  String? address,  String? placeId)  $default,) {final _that = this;
switch (_that) {
case _JourneyPlace():
return $default(_that.name,_that.lat,_that.lng,_that.address,_that.placeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  double lat,  double lng,  String? address,  String? placeId)?  $default,) {final _that = this;
switch (_that) {
case _JourneyPlace() when $default != null:
return $default(_that.name,_that.lat,_that.lng,_that.address,_that.placeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JourneyPlace extends JourneyPlace {
  const _JourneyPlace({required this.name, required this.lat, required this.lng, this.address, this.placeId}): super._();
  factory _JourneyPlace.fromJson(Map<String, dynamic> json) => _$JourneyPlaceFromJson(json);

@override final  String name;
@override final  double lat;
@override final  double lng;
/// The provider's fuller description, when it gave one.
@override final  String? address;
/// The provider's id for the place, when it has one.
@override final  String? placeId;

/// Create a copy of JourneyPlace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JourneyPlaceCopyWith<_JourneyPlace> get copyWith => __$JourneyPlaceCopyWithImpl<_JourneyPlace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JourneyPlaceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JourneyPlace&&(identical(other.name, name) || other.name == name)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.address, address) || other.address == address)&&(identical(other.placeId, placeId) || other.placeId == placeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,lat,lng,address,placeId);

@override
String toString() {
  return 'JourneyPlace(name: $name, lat: $lat, lng: $lng, address: $address, placeId: $placeId)';
}


}

/// @nodoc
abstract mixin class _$JourneyPlaceCopyWith<$Res> implements $JourneyPlaceCopyWith<$Res> {
  factory _$JourneyPlaceCopyWith(_JourneyPlace value, $Res Function(_JourneyPlace) _then) = __$JourneyPlaceCopyWithImpl;
@override @useResult
$Res call({
 String name, double lat, double lng, String? address, String? placeId
});




}
/// @nodoc
class __$JourneyPlaceCopyWithImpl<$Res>
    implements _$JourneyPlaceCopyWith<$Res> {
  __$JourneyPlaceCopyWithImpl(this._self, this._then);

  final _JourneyPlace _self;
  final $Res Function(_JourneyPlace) _then;

/// Create a copy of JourneyPlace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? lat = null,Object? lng = null,Object? address = freezed,Object? placeId = freezed,}) {
  return _then(_JourneyPlace(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,placeId: freezed == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
