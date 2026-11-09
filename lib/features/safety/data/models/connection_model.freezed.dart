// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConnectionPermissions {

 bool get safetyAlerts;
/// Create a copy of ConnectionPermissions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionPermissionsCopyWith<ConnectionPermissions> get copyWith => _$ConnectionPermissionsCopyWithImpl<ConnectionPermissions>(this as ConnectionPermissions, _$identity);

  /// Serializes this ConnectionPermissions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionPermissions&&(identical(other.safetyAlerts, safetyAlerts) || other.safetyAlerts == safetyAlerts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,safetyAlerts);

@override
String toString() {
  return 'ConnectionPermissions(safetyAlerts: $safetyAlerts)';
}


}

/// @nodoc
abstract mixin class $ConnectionPermissionsCopyWith<$Res>  {
  factory $ConnectionPermissionsCopyWith(ConnectionPermissions value, $Res Function(ConnectionPermissions) _then) = _$ConnectionPermissionsCopyWithImpl;
@useResult
$Res call({
 bool safetyAlerts
});




}
/// @nodoc
class _$ConnectionPermissionsCopyWithImpl<$Res>
    implements $ConnectionPermissionsCopyWith<$Res> {
  _$ConnectionPermissionsCopyWithImpl(this._self, this._then);

  final ConnectionPermissions _self;
  final $Res Function(ConnectionPermissions) _then;

/// Create a copy of ConnectionPermissions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? safetyAlerts = null,}) {
  return _then(_self.copyWith(
safetyAlerts: null == safetyAlerts ? _self.safetyAlerts : safetyAlerts // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConnectionPermissions].
extension ConnectionPermissionsPatterns on ConnectionPermissions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionPermissions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionPermissions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionPermissions value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionPermissions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionPermissions value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionPermissions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool safetyAlerts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionPermissions() when $default != null:
return $default(_that.safetyAlerts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool safetyAlerts)  $default,) {final _that = this;
switch (_that) {
case _ConnectionPermissions():
return $default(_that.safetyAlerts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool safetyAlerts)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionPermissions() when $default != null:
return $default(_that.safetyAlerts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConnectionPermissions implements ConnectionPermissions {
  const _ConnectionPermissions({this.safetyAlerts = false});
  factory _ConnectionPermissions.fromJson(Map<String, dynamic> json) => _$ConnectionPermissionsFromJson(json);

@override@JsonKey() final  bool safetyAlerts;

/// Create a copy of ConnectionPermissions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionPermissionsCopyWith<_ConnectionPermissions> get copyWith => __$ConnectionPermissionsCopyWithImpl<_ConnectionPermissions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConnectionPermissionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionPermissions&&(identical(other.safetyAlerts, safetyAlerts) || other.safetyAlerts == safetyAlerts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,safetyAlerts);

@override
String toString() {
  return 'ConnectionPermissions(safetyAlerts: $safetyAlerts)';
}


}

/// @nodoc
abstract mixin class _$ConnectionPermissionsCopyWith<$Res> implements $ConnectionPermissionsCopyWith<$Res> {
  factory _$ConnectionPermissionsCopyWith(_ConnectionPermissions value, $Res Function(_ConnectionPermissions) _then) = __$ConnectionPermissionsCopyWithImpl;
@override @useResult
$Res call({
 bool safetyAlerts
});




}
/// @nodoc
class __$ConnectionPermissionsCopyWithImpl<$Res>
    implements _$ConnectionPermissionsCopyWith<$Res> {
  __$ConnectionPermissionsCopyWithImpl(this._self, this._then);

  final _ConnectionPermissions _self;
  final $Res Function(_ConnectionPermissions) _then;

/// Create a copy of ConnectionPermissions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? safetyAlerts = null,}) {
  return _then(_ConnectionPermissions(
safetyAlerts: null == safetyAlerts ? _self.safetyAlerts : safetyAlerts // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ConnectionModel {

 String get ownerUid; String get contactUid;/// Their name when they connected. It does not follow a later rename.
 String get contactName; ConnectionStatus get status; String get inviteId;/// When the invite was made. UTC.
@TimestampConverter() DateTime get createdAt;/// The server's time of the acceptance. UTC.
@TimestampConverter() DateTime get acceptedAt; ConnectionPermissions get permissions;/// The owner's own word for them; the other side never sees it.
 String? get nickname;@NullableTimestampConverter() DateTime? get revokedAt;/// Who ended it.
 String? get revokedBy;
/// Create a copy of ConnectionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionModelCopyWith<ConnectionModel> get copyWith => _$ConnectionModelCopyWithImpl<ConnectionModel>(this as ConnectionModel, _$identity);

  /// Serializes this ConnectionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionModel&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.contactUid, contactUid) || other.contactUid == contactUid)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.status, status) || other.status == status)&&(identical(other.inviteId, inviteId) || other.inviteId == inviteId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.revokedBy, revokedBy) || other.revokedBy == revokedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerUid,contactUid,contactName,status,inviteId,createdAt,acceptedAt,permissions,nickname,revokedAt,revokedBy);

@override
String toString() {
  return 'ConnectionModel(ownerUid: $ownerUid, contactUid: $contactUid, contactName: $contactName, status: $status, inviteId: $inviteId, createdAt: $createdAt, acceptedAt: $acceptedAt, permissions: $permissions, nickname: $nickname, revokedAt: $revokedAt, revokedBy: $revokedBy)';
}


}

/// @nodoc
abstract mixin class $ConnectionModelCopyWith<$Res>  {
  factory $ConnectionModelCopyWith(ConnectionModel value, $Res Function(ConnectionModel) _then) = _$ConnectionModelCopyWithImpl;
@useResult
$Res call({
 String ownerUid, String contactUid, String contactName, ConnectionStatus status, String inviteId,@TimestampConverter() DateTime createdAt,@TimestampConverter() DateTime acceptedAt, ConnectionPermissions permissions, String? nickname,@NullableTimestampConverter() DateTime? revokedAt, String? revokedBy
});


$ConnectionPermissionsCopyWith<$Res> get permissions;

}
/// @nodoc
class _$ConnectionModelCopyWithImpl<$Res>
    implements $ConnectionModelCopyWith<$Res> {
  _$ConnectionModelCopyWithImpl(this._self, this._then);

  final ConnectionModel _self;
  final $Res Function(ConnectionModel) _then;

/// Create a copy of ConnectionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerUid = null,Object? contactUid = null,Object? contactName = null,Object? status = null,Object? inviteId = null,Object? createdAt = null,Object? acceptedAt = null,Object? permissions = null,Object? nickname = freezed,Object? revokedAt = freezed,Object? revokedBy = freezed,}) {
  return _then(_self.copyWith(
ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as String,contactUid: null == contactUid ? _self.contactUid : contactUid // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,inviteId: null == inviteId ? _self.inviteId : inviteId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedAt: null == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ConnectionPermissions,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedBy: freezed == revokedBy ? _self.revokedBy : revokedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ConnectionModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConnectionPermissionsCopyWith<$Res> get permissions {
  
  return $ConnectionPermissionsCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConnectionModel].
extension ConnectionModelPatterns on ConnectionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectionModel value)  $default,){
final _that = this;
switch (_that) {
case _ConnectionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectionModel value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerUid,  String contactUid,  String contactName,  ConnectionStatus status,  String inviteId, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime acceptedAt,  ConnectionPermissions permissions,  String? nickname, @NullableTimestampConverter()  DateTime? revokedAt,  String? revokedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectionModel() when $default != null:
return $default(_that.ownerUid,_that.contactUid,_that.contactName,_that.status,_that.inviteId,_that.createdAt,_that.acceptedAt,_that.permissions,_that.nickname,_that.revokedAt,_that.revokedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerUid,  String contactUid,  String contactName,  ConnectionStatus status,  String inviteId, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime acceptedAt,  ConnectionPermissions permissions,  String? nickname, @NullableTimestampConverter()  DateTime? revokedAt,  String? revokedBy)  $default,) {final _that = this;
switch (_that) {
case _ConnectionModel():
return $default(_that.ownerUid,_that.contactUid,_that.contactName,_that.status,_that.inviteId,_that.createdAt,_that.acceptedAt,_that.permissions,_that.nickname,_that.revokedAt,_that.revokedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerUid,  String contactUid,  String contactName,  ConnectionStatus status,  String inviteId, @TimestampConverter()  DateTime createdAt, @TimestampConverter()  DateTime acceptedAt,  ConnectionPermissions permissions,  String? nickname, @NullableTimestampConverter()  DateTime? revokedAt,  String? revokedBy)?  $default,) {final _that = this;
switch (_that) {
case _ConnectionModel() when $default != null:
return $default(_that.ownerUid,_that.contactUid,_that.contactName,_that.status,_that.inviteId,_that.createdAt,_that.acceptedAt,_that.permissions,_that.nickname,_that.revokedAt,_that.revokedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConnectionModel extends ConnectionModel {
  const _ConnectionModel({required this.ownerUid, required this.contactUid, required this.contactName, required this.status, required this.inviteId, @TimestampConverter() required this.createdAt, @TimestampConverter() required this.acceptedAt, this.permissions = const ConnectionPermissions(), this.nickname, @NullableTimestampConverter() this.revokedAt, this.revokedBy}): super._();
  factory _ConnectionModel.fromJson(Map<String, dynamic> json) => _$ConnectionModelFromJson(json);

@override final  String ownerUid;
@override final  String contactUid;
/// Their name when they connected. It does not follow a later rename.
@override final  String contactName;
@override final  ConnectionStatus status;
@override final  String inviteId;
/// When the invite was made. UTC.
@override@TimestampConverter() final  DateTime createdAt;
/// The server's time of the acceptance. UTC.
@override@TimestampConverter() final  DateTime acceptedAt;
@override@JsonKey() final  ConnectionPermissions permissions;
/// The owner's own word for them; the other side never sees it.
@override final  String? nickname;
@override@NullableTimestampConverter() final  DateTime? revokedAt;
/// Who ended it.
@override final  String? revokedBy;

/// Create a copy of ConnectionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectionModelCopyWith<_ConnectionModel> get copyWith => __$ConnectionModelCopyWithImpl<_ConnectionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConnectionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectionModel&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.contactUid, contactUid) || other.contactUid == contactUid)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.status, status) || other.status == status)&&(identical(other.inviteId, inviteId) || other.inviteId == inviteId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.revokedBy, revokedBy) || other.revokedBy == revokedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerUid,contactUid,contactName,status,inviteId,createdAt,acceptedAt,permissions,nickname,revokedAt,revokedBy);

@override
String toString() {
  return 'ConnectionModel(ownerUid: $ownerUid, contactUid: $contactUid, contactName: $contactName, status: $status, inviteId: $inviteId, createdAt: $createdAt, acceptedAt: $acceptedAt, permissions: $permissions, nickname: $nickname, revokedAt: $revokedAt, revokedBy: $revokedBy)';
}


}

/// @nodoc
abstract mixin class _$ConnectionModelCopyWith<$Res> implements $ConnectionModelCopyWith<$Res> {
  factory _$ConnectionModelCopyWith(_ConnectionModel value, $Res Function(_ConnectionModel) _then) = __$ConnectionModelCopyWithImpl;
@override @useResult
$Res call({
 String ownerUid, String contactUid, String contactName, ConnectionStatus status, String inviteId,@TimestampConverter() DateTime createdAt,@TimestampConverter() DateTime acceptedAt, ConnectionPermissions permissions, String? nickname,@NullableTimestampConverter() DateTime? revokedAt, String? revokedBy
});


@override $ConnectionPermissionsCopyWith<$Res> get permissions;

}
/// @nodoc
class __$ConnectionModelCopyWithImpl<$Res>
    implements _$ConnectionModelCopyWith<$Res> {
  __$ConnectionModelCopyWithImpl(this._self, this._then);

  final _ConnectionModel _self;
  final $Res Function(_ConnectionModel) _then;

/// Create a copy of ConnectionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerUid = null,Object? contactUid = null,Object? contactName = null,Object? status = null,Object? inviteId = null,Object? createdAt = null,Object? acceptedAt = null,Object? permissions = null,Object? nickname = freezed,Object? revokedAt = freezed,Object? revokedBy = freezed,}) {
  return _then(_ConnectionModel(
ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as String,contactUid: null == contactUid ? _self.contactUid : contactUid // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ConnectionStatus,inviteId: null == inviteId ? _self.inviteId : inviteId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,acceptedAt: null == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ConnectionPermissions,nickname: freezed == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String?,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedBy: freezed == revokedBy ? _self.revokedBy : revokedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ConnectionModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConnectionPermissionsCopyWith<$Res> get permissions {
  
  return $ConnectionPermissionsCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}
}

// dart format on
