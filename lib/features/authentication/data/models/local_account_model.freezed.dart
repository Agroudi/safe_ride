// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'local_account_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LocalAccountModel {

 UserModel get user;/// Base64.
 String get salt;/// Base64 PBKDF2-HMAC-SHA256 of the password with [salt].
 String get hash;/// The rounds [hash] was made with, so raising the default later still
/// verifies older accounts.
 int get iterations;
/// Create a copy of LocalAccountModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalAccountModelCopyWith<LocalAccountModel> get copyWith => _$LocalAccountModelCopyWithImpl<LocalAccountModel>(this as LocalAccountModel, _$identity);

  /// Serializes this LocalAccountModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalAccountModel&&(identical(other.user, user) || other.user == user)&&(identical(other.salt, salt) || other.salt == salt)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.iterations, iterations) || other.iterations == iterations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user,salt,hash,iterations);

@override
String toString() {
  return 'LocalAccountModel(user: $user, salt: $salt, hash: $hash, iterations: $iterations)';
}


}

/// @nodoc
abstract mixin class $LocalAccountModelCopyWith<$Res>  {
  factory $LocalAccountModelCopyWith(LocalAccountModel value, $Res Function(LocalAccountModel) _then) = _$LocalAccountModelCopyWithImpl;
@useResult
$Res call({
 UserModel user, String salt, String hash, int iterations
});


$UserModelCopyWith<$Res> get user;

}
/// @nodoc
class _$LocalAccountModelCopyWithImpl<$Res>
    implements $LocalAccountModelCopyWith<$Res> {
  _$LocalAccountModelCopyWithImpl(this._self, this._then);

  final LocalAccountModel _self;
  final $Res Function(LocalAccountModel) _then;

/// Create a copy of LocalAccountModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? salt = null,Object? hash = null,Object? iterations = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserModel,salt: null == salt ? _self.salt : salt // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,iterations: null == iterations ? _self.iterations : iterations // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of LocalAccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserModelCopyWith<$Res> get user {
  
  return $UserModelCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LocalAccountModel].
extension LocalAccountModelPatterns on LocalAccountModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocalAccountModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocalAccountModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocalAccountModel value)  $default,){
final _that = this;
switch (_that) {
case _LocalAccountModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocalAccountModel value)?  $default,){
final _that = this;
switch (_that) {
case _LocalAccountModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserModel user,  String salt,  String hash,  int iterations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalAccountModel() when $default != null:
return $default(_that.user,_that.salt,_that.hash,_that.iterations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserModel user,  String salt,  String hash,  int iterations)  $default,) {final _that = this;
switch (_that) {
case _LocalAccountModel():
return $default(_that.user,_that.salt,_that.hash,_that.iterations);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserModel user,  String salt,  String hash,  int iterations)?  $default,) {final _that = this;
switch (_that) {
case _LocalAccountModel() when $default != null:
return $default(_that.user,_that.salt,_that.hash,_that.iterations);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocalAccountModel implements LocalAccountModel {
  const _LocalAccountModel({required this.user, required this.salt, required this.hash, required this.iterations});
  factory _LocalAccountModel.fromJson(Map<String, dynamic> json) => _$LocalAccountModelFromJson(json);

@override final  UserModel user;
/// Base64.
@override final  String salt;
/// Base64 PBKDF2-HMAC-SHA256 of the password with [salt].
@override final  String hash;
/// The rounds [hash] was made with, so raising the default later still
/// verifies older accounts.
@override final  int iterations;

/// Create a copy of LocalAccountModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalAccountModelCopyWith<_LocalAccountModel> get copyWith => __$LocalAccountModelCopyWithImpl<_LocalAccountModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocalAccountModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalAccountModel&&(identical(other.user, user) || other.user == user)&&(identical(other.salt, salt) || other.salt == salt)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.iterations, iterations) || other.iterations == iterations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user,salt,hash,iterations);

@override
String toString() {
  return 'LocalAccountModel(user: $user, salt: $salt, hash: $hash, iterations: $iterations)';
}


}

/// @nodoc
abstract mixin class _$LocalAccountModelCopyWith<$Res> implements $LocalAccountModelCopyWith<$Res> {
  factory _$LocalAccountModelCopyWith(_LocalAccountModel value, $Res Function(_LocalAccountModel) _then) = __$LocalAccountModelCopyWithImpl;
@override @useResult
$Res call({
 UserModel user, String salt, String hash, int iterations
});


@override $UserModelCopyWith<$Res> get user;

}
/// @nodoc
class __$LocalAccountModelCopyWithImpl<$Res>
    implements _$LocalAccountModelCopyWith<$Res> {
  __$LocalAccountModelCopyWithImpl(this._self, this._then);

  final _LocalAccountModel _self;
  final $Res Function(_LocalAccountModel) _then;

/// Create a copy of LocalAccountModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? salt = null,Object? hash = null,Object? iterations = null,}) {
  return _then(_LocalAccountModel(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserModel,salt: null == salt ? _self.salt : salt // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,iterations: null == iterations ? _self.iterations : iterations // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of LocalAccountModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserModelCopyWith<$Res> get user {
  
  return $UserModelCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
