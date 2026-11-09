// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_invite_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConnectionInviteModel {

 String get token; String get inviterUid;/// Copied from the inviter's profile; the rules check that it is.
 String get inviterName;/// Only pending or accepted are stored: see [statusAt].
 ConnectionStatus get status;@TimestampConverter() DateTime get createdAt;@TimestampConverter() DateTime get expiresAt; String? get acceptedBy;@NullableTimestampConverter() DateTime? get acceptedAt;
/// Create a copy of ConnectionInviteModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionInviteModelCopyWith<ConnectionInviteModel> get copyWith => _$ConnectionInviteModelCopyWithImpl<ConnectionInviteModel>(this as ConnectionInviteModel, _$identity);

  /// Serializes this ConnectionInviteModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionInviteModel&&(identical(other.token, token) || other.token == token)&&(identical(other.inviterUid, inviterUid) || other.inviterUid == inviterUid)&&(identical(other.inviterName, inviterName) || other.inviterName == inviterName)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.acceptedBy, acceptedBy) || other.acceptedBy == acceptedBy)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,inviterUid,inviterName,status,createdAt,expiresAt,acceptedBy,acceptedAt);

@override
String toString() {
  return 'ConnectionInviteModel(token: $token, inviterUid: $inviterUid, inviterName: $inviterName, status: $status, createdAt: $createdAt, expiresAt: $expiresAt, acceptedBy: $acceptedBy, acceptedAt: $acceptedAt)';
}


}

/// @nodoc
abstract mixin class $ConnectionInviteModelCopyWith<$Res>  {
  factory $ConnectionInviteModelCopyWith(ConnectionInviteModel value, $Res Function(ConnectionInviteModel) _then) = _$ConnectionInviteModelCopyWithImpl;
@useResult
$Res call({
 String token, String inviterUid, String inviterName, ConnectionStatus status,@TimestampConverter() DateTime createdAt,@TimestampConverter() DateTime expiresAt, String? acceptedBy,@NullableTimestampConverter() DateTime? acceptedAt
});




}
/// @nodoc
class _$ConnectionInviteModelCopyWithImpl<$Res>
    implements $ConnectionInviteModelCopyWith<$Res> {
  _$ConnectionInviteModelCopyWithImpl(this._self, this._then);

  final ConnectionInviteModel _self;
  final $Res Function(ConnectionInviteModel) _then;

/// Create a copy of ConnectionInviteModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? inviterUid = null,Object? inviterName = null,Object? status = null,Object? createdAt = null,Object? expiresAt = null,Object? acceptedBy = freezed,Object? acceptedAt = freezed,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,inviterUid: null == inviterUid ? _self.inviterUid : inviterUid // ignore: cast_nullable_to_non_nullable
as String,inviterName: null == inviterName ? _self.inviterName : inviterName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedBy: freezed == acceptedBy ? _self.acceptedBy : acceptedBy // ignore: cast_nullable_to_non_nullable
as String?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ConnectionInviteModel].
extension ConnectionInviteModelPatterns on ConnectionInviteModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionInviteModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionInviteModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionInviteModel value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionInviteModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionInviteModel value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionInviteModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String inviterUid,  String inviterName,  ConnectionStatus status, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime expiresAt,  String? acceptedBy, @NullableTimestampConverter()  DateTime? acceptedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionInviteModel() when $default != null:
return $default(_that.token,_that.inviterUid,_that.inviterName,_that.status,_that.createdAt,_that.expiresAt,_that.acceptedBy,_that.acceptedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String inviterUid,  String inviterName,  ConnectionStatus status, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime expiresAt,  String? acceptedBy, @NullableTimestampConverter()  DateTime? acceptedAt)  $default,) {final _that = this;
switch (_that) {
case _ConnectionInviteModel():
return $default(_that.token,_that.inviterUid,_that.inviterName,_that.status,_that.createdAt,_that.expiresAt,_that.acceptedBy,_that.acceptedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String inviterUid,  String inviterName,  ConnectionStatus status, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime expiresAt,  String? acceptedBy, @NullableTimestampConverter()  DateTime? acceptedAt)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionInviteModel() when $default != null:
return $default(_that.token,_that.inviterUid,_that.inviterName,_that.status,_that.createdAt,_that.expiresAt,_that.acceptedBy,_that.acceptedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConnectionInviteModel extends ConnectionInviteModel {
  const _ConnectionInviteModel({required this.token, required this.inviterUid, required this.inviterName, required this.status, @TimestampConverter() required this.createdAt, @TimestampConverter() required this.expiresAt, this.acceptedBy, @NullableTimestampConverter() this.acceptedAt}): super._();
  factory _ConnectionInviteModel.fromJson(Map<String, dynamic> json) => _$ConnectionInviteModelFromJson(json);

@override final  String token;
@override final  String inviterUid;
/// Copied from the inviter's profile; the rules check that it is.
@override final  String inviterName;
/// Only pending or accepted are stored: see [statusAt].
@override final  ConnectionStatus status;
@override@TimestampConverter() final  DateTime createdAt;
@override@TimestampConverter() final  DateTime expiresAt;
@override final  String? acceptedBy;
@override@NullableTimestampConverter() final  DateTime? acceptedAt;

/// Create a copy of ConnectionInviteModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionInviteModelCopyWith<_ConnectionInviteModel> get copyWith => __$ConnectionInviteModelCopyWithImpl<_ConnectionInviteModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConnectionInviteModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionInviteModel&&(identical(other.token, token) || other.token == token)&&(identical(other.inviterUid, inviterUid) || other.inviterUid == inviterUid)&&(identical(other.inviterName, inviterName) || other.inviterName == inviterName)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.acceptedBy, acceptedBy) || other.acceptedBy == acceptedBy)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,inviterUid,inviterName,status,createdAt,expiresAt,acceptedBy,acceptedAt);

@override
String toString() {
  return 'ConnectionInviteModel(token: $token, inviterUid: $inviterUid, inviterName: $inviterName, status: $status, createdAt: $createdAt, expiresAt: $expiresAt, acceptedBy: $acceptedBy, acceptedAt: $acceptedAt)';
}


}

/// @nodoc
abstract mixin class _$ConnectionInviteModelCopyWith<$Res> implements $ConnectionInviteModelCopyWith<$Res> {
  factory _$ConnectionInviteModelCopyWith(_ConnectionInviteModel value, $Res Function(_ConnectionInviteModel) _then) = __$ConnectionInviteModelCopyWithImpl;
@override @useResult
$Res call({
 String token, String inviterUid, String inviterName, ConnectionStatus status,@TimestampConverter() DateTime createdAt,@TimestampConverter() DateTime expiresAt, String? acceptedBy,@NullableTimestampConverter() DateTime? acceptedAt
});




}
/// @nodoc
class __$ConnectionInviteModelCopyWithImpl<$Res>
    implements _$ConnectionInviteModelCopyWith<$Res> {
  __$ConnectionInviteModelCopyWithImpl(this._self, this._then);

  final _ConnectionInviteModel _self;
  final $Res Function(_ConnectionInviteModel) _then;

/// Create a copy of ConnectionInviteModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? inviterUid = null,Object? inviterName = null,Object? status = null,Object? createdAt = null,Object? expiresAt = null,Object? acceptedBy = freezed,Object? acceptedAt = freezed,}) {
  return _then(_ConnectionInviteModel(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,inviterUid: null == inviterUid ? _self.inviterUid : inviterUid // ignore: cast_nullable_to_non_nullable
as String,inviterName: null == inviterName ? _self.inviterName : inviterName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedBy: freezed == acceptedBy ? _self.acceptedBy : acceptedBy // ignore: cast_nullable_to_non_nullable
as String?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
