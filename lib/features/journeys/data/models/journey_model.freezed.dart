// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journey_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JourneyModel {

 String get id; String get origin; String get destination; JourneyStatus get status;/// UTC.
 DateTime get createdAt;/// UTC; the last change (an edit or a status).
 DateTime get updatedAt;/// UTC; when the user means to set off. Every journey planned from
/// batch 4 on has one; null only on a journey stored before the field
/// existed — shown as "not set", never guessed.
 DateTime? get departsAt;
/// Create a copy of JourneyModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JourneyModelCopyWith<JourneyModel> get copyWith => _$JourneyModelCopyWithImpl<JourneyModel>(this as JourneyModel, _$identity);

  /// Serializes this JourneyModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.departsAt, departsAt) || other.departsAt == departsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,origin,destination,status,createdAt,updatedAt,departsAt);

@override
String toString() {
  return 'JourneyModel(id: $id, origin: $origin, destination: $destination, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, departsAt: $departsAt)';
}


}

/// @nodoc
abstract mixin class $JourneyModelCopyWith<$Res>  {
  factory $JourneyModelCopyWith(JourneyModel value, $Res Function(JourneyModel) _then) = _$JourneyModelCopyWithImpl;
@useResult
$Res call({
 String id, String origin, String destination, JourneyStatus status, DateTime createdAt, DateTime updatedAt, DateTime? departsAt
});




}
/// @nodoc
class _$JourneyModelCopyWithImpl<$Res>
    implements $JourneyModelCopyWith<$Res> {
  _$JourneyModelCopyWithImpl(this._self, this._then);

  final JourneyModel _self;
  final $Res Function(JourneyModel) _then;

/// Create a copy of JourneyModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? origin = null,Object? destination = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? departsAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JourneyStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,departsAt: freezed == departsAt ? _self.departsAt : departsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [JourneyModel].
extension JourneyModelPatterns on JourneyModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JourneyModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JourneyModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JourneyModel value)  $default,){
final _that = this;
switch (_that) {
case _JourneyModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JourneyModel value)?  $default,){
final _that = this;
switch (_that) {
case _JourneyModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String origin,  String destination,  JourneyStatus status,  DateTime createdAt,  DateTime updatedAt,  DateTime? departsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JourneyModel() when $default != null:
return $default(_that.id,_that.origin,_that.destination,_that.status,_that.createdAt,_that.updatedAt,_that.departsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String origin,  String destination,  JourneyStatus status,  DateTime createdAt,  DateTime updatedAt,  DateTime? departsAt)  $default,) {final _that = this;
switch (_that) {
case _JourneyModel():
return $default(_that.id,_that.origin,_that.destination,_that.status,_that.createdAt,_that.updatedAt,_that.departsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String origin,  String destination,  JourneyStatus status,  DateTime createdAt,  DateTime updatedAt,  DateTime? departsAt)?  $default,) {final _that = this;
switch (_that) {
case _JourneyModel() when $default != null:
return $default(_that.id,_that.origin,_that.destination,_that.status,_that.createdAt,_that.updatedAt,_that.departsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JourneyModel implements JourneyModel {
  const _JourneyModel({required this.id, required this.origin, required this.destination, required this.status, required this.createdAt, required this.updatedAt, this.departsAt});
  factory _JourneyModel.fromJson(Map<String, dynamic> json) => _$JourneyModelFromJson(json);

@override final  String id;
@override final  String origin;
@override final  String destination;
@override final  JourneyStatus status;
/// UTC.
@override final  DateTime createdAt;
/// UTC; the last change (an edit or a status).
@override final  DateTime updatedAt;
/// UTC; when the user means to set off. Every journey planned from
/// batch 4 on has one; null only on a journey stored before the field
/// existed — shown as "not set", never guessed.
@override final  DateTime? departsAt;

/// Create a copy of JourneyModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JourneyModelCopyWith<_JourneyModel> get copyWith => __$JourneyModelCopyWithImpl<_JourneyModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JourneyModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JourneyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.departsAt, departsAt) || other.departsAt == departsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,origin,destination,status,createdAt,updatedAt,departsAt);

@override
String toString() {
  return 'JourneyModel(id: $id, origin: $origin, destination: $destination, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, departsAt: $departsAt)';
}


}

/// @nodoc
abstract mixin class _$JourneyModelCopyWith<$Res> implements $JourneyModelCopyWith<$Res> {
  factory _$JourneyModelCopyWith(_JourneyModel value, $Res Function(_JourneyModel) _then) = __$JourneyModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String origin, String destination, JourneyStatus status, DateTime createdAt, DateTime updatedAt, DateTime? departsAt
});




}
/// @nodoc
class __$JourneyModelCopyWithImpl<$Res>
    implements _$JourneyModelCopyWith<$Res> {
  __$JourneyModelCopyWithImpl(this._self, this._then);

  final _JourneyModel _self;
  final $Res Function(_JourneyModel) _then;

/// Create a copy of JourneyModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? origin = null,Object? destination = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? departsAt = freezed,}) {
  return _then(_JourneyModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JourneyStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,departsAt: freezed == departsAt ? _self.departsAt : departsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
