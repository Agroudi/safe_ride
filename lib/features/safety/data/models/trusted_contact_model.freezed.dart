// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trusted_contact_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrustedContactModel {

 String get id; String get fullName;/// As typed; compared by its digits only.
 String get phone;/// UTC.
 DateTime get createdAt;/// "Sister", "Friend" — optional, the user's own word.
 String? get relationship;
/// Create a copy of TrustedContactModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrustedContactModelCopyWith<TrustedContactModel> get copyWith => _$TrustedContactModelCopyWithImpl<TrustedContactModel>(this as TrustedContactModel, _$identity);

  /// Serializes this TrustedContactModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrustedContactModel&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.relationship, relationship) || other.relationship == relationship));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,phone,createdAt,relationship);

@override
String toString() {
  return 'TrustedContactModel(id: $id, fullName: $fullName, phone: $phone, createdAt: $createdAt, relationship: $relationship)';
}


}

/// @nodoc
abstract mixin class $TrustedContactModelCopyWith<$Res>  {
  factory $TrustedContactModelCopyWith(TrustedContactModel value, $Res Function(TrustedContactModel) _then) = _$TrustedContactModelCopyWithImpl;
@useResult
$Res call({
 String id, String fullName, String phone, DateTime createdAt, String? relationship
});




}
/// @nodoc
class _$TrustedContactModelCopyWithImpl<$Res>
    implements $TrustedContactModelCopyWith<$Res> {
  _$TrustedContactModelCopyWithImpl(this._self, this._then);

  final TrustedContactModel _self;
  final $Res Function(TrustedContactModel) _then;

/// Create a copy of TrustedContactModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fullName = null,Object? phone = null,Object? createdAt = null,Object? relationship = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,relationship: freezed == relationship ? _self.relationship : relationship // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrustedContactModel].
extension TrustedContactModelPatterns on TrustedContactModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrustedContactModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrustedContactModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrustedContactModel value)  $default,){
final _that = this;
switch (_that) {
case _TrustedContactModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrustedContactModel value)?  $default,){
final _that = this;
switch (_that) {
case _TrustedContactModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fullName,  String phone,  DateTime createdAt,  String? relationship)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrustedContactModel() when $default != null:
return $default(_that.id,_that.fullName,_that.phone,_that.createdAt,_that.relationship);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fullName,  String phone,  DateTime createdAt,  String? relationship)  $default,) {final _that = this;
switch (_that) {
case _TrustedContactModel():
return $default(_that.id,_that.fullName,_that.phone,_that.createdAt,_that.relationship);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fullName,  String phone,  DateTime createdAt,  String? relationship)?  $default,) {final _that = this;
switch (_that) {
case _TrustedContactModel() when $default != null:
return $default(_that.id,_that.fullName,_that.phone,_that.createdAt,_that.relationship);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrustedContactModel implements TrustedContactModel {
  const _TrustedContactModel({required this.id, required this.fullName, required this.phone, required this.createdAt, this.relationship});
  factory _TrustedContactModel.fromJson(Map<String, dynamic> json) => _$TrustedContactModelFromJson(json);

@override final  String id;
@override final  String fullName;
/// As typed; compared by its digits only.
@override final  String phone;
/// UTC.
@override final  DateTime createdAt;
/// "Sister", "Friend" — optional, the user's own word.
@override final  String? relationship;

/// Create a copy of TrustedContactModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrustedContactModelCopyWith<_TrustedContactModel> get copyWith => __$TrustedContactModelCopyWithImpl<_TrustedContactModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrustedContactModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrustedContactModel&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.relationship, relationship) || other.relationship == relationship));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,phone,createdAt,relationship);

@override
String toString() {
  return 'TrustedContactModel(id: $id, fullName: $fullName, phone: $phone, createdAt: $createdAt, relationship: $relationship)';
}


}

/// @nodoc
abstract mixin class _$TrustedContactModelCopyWith<$Res> implements $TrustedContactModelCopyWith<$Res> {
  factory _$TrustedContactModelCopyWith(_TrustedContactModel value, $Res Function(_TrustedContactModel) _then) = __$TrustedContactModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String fullName, String phone, DateTime createdAt, String? relationship
});




}
/// @nodoc
class __$TrustedContactModelCopyWithImpl<$Res>
    implements _$TrustedContactModelCopyWith<$Res> {
  __$TrustedContactModelCopyWithImpl(this._self, this._then);

  final _TrustedContactModel _self;
  final $Res Function(_TrustedContactModel) _then;

/// Create a copy of TrustedContactModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fullName = null,Object? phone = null,Object? createdAt = null,Object? relationship = freezed,}) {
  return _then(_TrustedContactModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,relationship: freezed == relationship ? _self.relationship : relationship // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
