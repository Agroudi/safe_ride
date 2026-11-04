// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'escalation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Escalation {

 EscalationStatus get status;/// Why it was rejected, or why there was nobody to alert.
 String? get reason; int get recipients; int get accepted; int get failed;
/// Create a copy of Escalation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EscalationCopyWith<Escalation> get copyWith => _$EscalationCopyWithImpl<Escalation>(this as Escalation, _$identity);

  /// Serializes this Escalation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Escalation&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.recipients, recipients) || other.recipients == recipients)&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.failed, failed) || other.failed == failed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,reason,recipients,accepted,failed);

@override
String toString() {
  return 'Escalation(status: $status, reason: $reason, recipients: $recipients, accepted: $accepted, failed: $failed)';
}


}

/// @nodoc
abstract mixin class $EscalationCopyWith<$Res>  {
  factory $EscalationCopyWith(Escalation value, $Res Function(Escalation) _then) = _$EscalationCopyWithImpl;
@useResult
$Res call({
 EscalationStatus status, String? reason, int recipients, int accepted, int failed
});




}
/// @nodoc
class _$EscalationCopyWithImpl<$Res>
    implements $EscalationCopyWith<$Res> {
  _$EscalationCopyWithImpl(this._self, this._then);

  final Escalation _self;
  final $Res Function(Escalation) _then;

/// Create a copy of Escalation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? reason = freezed,Object? recipients = null,Object? accepted = null,Object? failed = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EscalationStatus,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as int,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Escalation].
extension EscalationPatterns on Escalation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Escalation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Escalation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Escalation value)  $default,){
final _that = this;
switch (_that) {
case _Escalation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Escalation value)?  $default,){
final _that = this;
switch (_that) {
case _Escalation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EscalationStatus status,  String? reason,  int recipients,  int accepted,  int failed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Escalation() when $default != null:
return $default(_that.status,_that.reason,_that.recipients,_that.accepted,_that.failed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EscalationStatus status,  String? reason,  int recipients,  int accepted,  int failed)  $default,) {final _that = this;
switch (_that) {
case _Escalation():
return $default(_that.status,_that.reason,_that.recipients,_that.accepted,_that.failed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EscalationStatus status,  String? reason,  int recipients,  int accepted,  int failed)?  $default,) {final _that = this;
switch (_that) {
case _Escalation() when $default != null:
return $default(_that.status,_that.reason,_that.recipients,_that.accepted,_that.failed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Escalation implements Escalation {
  const _Escalation({required this.status, this.reason, this.recipients = 0, this.accepted = 0, this.failed = 0});
  factory _Escalation.fromJson(Map<String, dynamic> json) => _$EscalationFromJson(json);

@override final  EscalationStatus status;
/// Why it was rejected, or why there was nobody to alert.
@override final  String? reason;
@override@JsonKey() final  int recipients;
@override@JsonKey() final  int accepted;
@override@JsonKey() final  int failed;

/// Create a copy of Escalation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EscalationCopyWith<_Escalation> get copyWith => __$EscalationCopyWithImpl<_Escalation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EscalationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Escalation&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.recipients, recipients) || other.recipients == recipients)&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.failed, failed) || other.failed == failed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,reason,recipients,accepted,failed);

@override
String toString() {
  return 'Escalation(status: $status, reason: $reason, recipients: $recipients, accepted: $accepted, failed: $failed)';
}


}

/// @nodoc
abstract mixin class _$EscalationCopyWith<$Res> implements $EscalationCopyWith<$Res> {
  factory _$EscalationCopyWith(_Escalation value, $Res Function(_Escalation) _then) = __$EscalationCopyWithImpl;
@override @useResult
$Res call({
 EscalationStatus status, String? reason, int recipients, int accepted, int failed
});




}
/// @nodoc
class __$EscalationCopyWithImpl<$Res>
    implements _$EscalationCopyWith<$Res> {
  __$EscalationCopyWithImpl(this._self, this._then);

  final _Escalation _self;
  final $Res Function(_Escalation) _then;

/// Create a copy of Escalation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? reason = freezed,Object? recipients = null,Object? accepted = null,Object? failed = null,}) {
  return _then(_Escalation(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EscalationStatus,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as int,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
