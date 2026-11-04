// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'safety_check.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SafetyCheck {

 String get id; String get incidentId; String get journeyId; String get uid; SafetyCheckStatus get status;/// When it was asked, and when the answer is due (UTC).
 DateTime get startedAt; DateTime get deadline; DateTime? get confirmedAt;/// The deadline that passed (UTC), and when the app noticed — later,
/// when the app was suspended meanwhile.
 DateTime? get timedOutAt; DateTime? get timeoutProcessedAt; DateTime? get escalationReadyAt; DateTime? get cancelledAt; SafetyCheckCancelReason? get cancelReason;/// When the escalation request was written on this phone, and when the
/// server confirmed having it. Apart after an offline stretch.
 DateTime? get escalationQueuedAt; DateTime? get escalationSyncedAt;
/// Create a copy of SafetyCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SafetyCheckCopyWith<SafetyCheck> get copyWith => _$SafetyCheckCopyWithImpl<SafetyCheck>(this as SafetyCheck, _$identity);

  /// Serializes this SafetyCheck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SafetyCheck&&(identical(other.id, id) || other.id == id)&&(identical(other.incidentId, incidentId) || other.incidentId == incidentId)&&(identical(other.journeyId, journeyId) || other.journeyId == journeyId)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.deadline, deadline) || other.deadline == deadline)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.timedOutAt, timedOutAt) || other.timedOutAt == timedOutAt)&&(identical(other.timeoutProcessedAt, timeoutProcessedAt) || other.timeoutProcessedAt == timeoutProcessedAt)&&(identical(other.escalationReadyAt, escalationReadyAt) || other.escalationReadyAt == escalationReadyAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancelReason, cancelReason) || other.cancelReason == cancelReason)&&(identical(other.escalationQueuedAt, escalationQueuedAt) || other.escalationQueuedAt == escalationQueuedAt)&&(identical(other.escalationSyncedAt, escalationSyncedAt) || other.escalationSyncedAt == escalationSyncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,incidentId,journeyId,uid,status,startedAt,deadline,confirmedAt,timedOutAt,timeoutProcessedAt,escalationReadyAt,cancelledAt,cancelReason,escalationQueuedAt,escalationSyncedAt);

@override
String toString() {
  return 'SafetyCheck(id: $id, incidentId: $incidentId, journeyId: $journeyId, uid: $uid, status: $status, startedAt: $startedAt, deadline: $deadline, confirmedAt: $confirmedAt, timedOutAt: $timedOutAt, timeoutProcessedAt: $timeoutProcessedAt, escalationReadyAt: $escalationReadyAt, cancelledAt: $cancelledAt, cancelReason: $cancelReason, escalationQueuedAt: $escalationQueuedAt, escalationSyncedAt: $escalationSyncedAt)';
}


}

/// @nodoc
abstract mixin class $SafetyCheckCopyWith<$Res>  {
  factory $SafetyCheckCopyWith(SafetyCheck value, $Res Function(SafetyCheck) _then) = _$SafetyCheckCopyWithImpl;
@useResult
$Res call({
 String id, String incidentId, String journeyId, String uid, SafetyCheckStatus status, DateTime startedAt, DateTime deadline, DateTime? confirmedAt, DateTime? timedOutAt, DateTime? timeoutProcessedAt, DateTime? escalationReadyAt, DateTime? cancelledAt, SafetyCheckCancelReason? cancelReason, DateTime? escalationQueuedAt, DateTime? escalationSyncedAt
});




}
/// @nodoc
class _$SafetyCheckCopyWithImpl<$Res>
    implements $SafetyCheckCopyWith<$Res> {
  _$SafetyCheckCopyWithImpl(this._self, this._then);

  final SafetyCheck _self;
  final $Res Function(SafetyCheck) _then;

/// Create a copy of SafetyCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? incidentId = null,Object? journeyId = null,Object? uid = null,Object? status = null,Object? startedAt = null,Object? deadline = null,Object? confirmedAt = freezed,Object? timedOutAt = freezed,Object? timeoutProcessedAt = freezed,Object? escalationReadyAt = freezed,Object? cancelledAt = freezed,Object? cancelReason = freezed,Object? escalationQueuedAt = freezed,Object? escalationSyncedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,incidentId: null == incidentId ? _self.incidentId : incidentId // ignore: cast_nullable_to_non_nullable
as String,journeyId: null == journeyId ? _self.journeyId : journeyId // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SafetyCheckStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deadline: null == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as DateTime,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timedOutAt: freezed == timedOutAt ? _self.timedOutAt : timedOutAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timeoutProcessedAt: freezed == timeoutProcessedAt ? _self.timeoutProcessedAt : timeoutProcessedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalationReadyAt: freezed == escalationReadyAt ? _self.escalationReadyAt : escalationReadyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelReason: freezed == cancelReason ? _self.cancelReason : cancelReason // ignore: cast_nullable_to_non_nullable
as SafetyCheckCancelReason?,escalationQueuedAt: freezed == escalationQueuedAt ? _self.escalationQueuedAt : escalationQueuedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalationSyncedAt: freezed == escalationSyncedAt ? _self.escalationSyncedAt : escalationSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SafetyCheck].
extension SafetyCheckPatterns on SafetyCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SafetyCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SafetyCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SafetyCheck value)  $default,){
final _that = this;
switch (_that) {
case _SafetyCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SafetyCheck value)?  $default,){
final _that = this;
switch (_that) {
case _SafetyCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String incidentId,  String journeyId,  String uid,  SafetyCheckStatus status,  DateTime startedAt,  DateTime deadline,  DateTime? confirmedAt,  DateTime? timedOutAt,  DateTime? timeoutProcessedAt,  DateTime? escalationReadyAt,  DateTime? cancelledAt,  SafetyCheckCancelReason? cancelReason,  DateTime? escalationQueuedAt,  DateTime? escalationSyncedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SafetyCheck() when $default != null:
return $default(_that.id,_that.incidentId,_that.journeyId,_that.uid,_that.status,_that.startedAt,_that.deadline,_that.confirmedAt,_that.timedOutAt,_that.timeoutProcessedAt,_that.escalationReadyAt,_that.cancelledAt,_that.cancelReason,_that.escalationQueuedAt,_that.escalationSyncedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String incidentId,  String journeyId,  String uid,  SafetyCheckStatus status,  DateTime startedAt,  DateTime deadline,  DateTime? confirmedAt,  DateTime? timedOutAt,  DateTime? timeoutProcessedAt,  DateTime? escalationReadyAt,  DateTime? cancelledAt,  SafetyCheckCancelReason? cancelReason,  DateTime? escalationQueuedAt,  DateTime? escalationSyncedAt)  $default,) {final _that = this;
switch (_that) {
case _SafetyCheck():
return $default(_that.id,_that.incidentId,_that.journeyId,_that.uid,_that.status,_that.startedAt,_that.deadline,_that.confirmedAt,_that.timedOutAt,_that.timeoutProcessedAt,_that.escalationReadyAt,_that.cancelledAt,_that.cancelReason,_that.escalationQueuedAt,_that.escalationSyncedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String incidentId,  String journeyId,  String uid,  SafetyCheckStatus status,  DateTime startedAt,  DateTime deadline,  DateTime? confirmedAt,  DateTime? timedOutAt,  DateTime? timeoutProcessedAt,  DateTime? escalationReadyAt,  DateTime? cancelledAt,  SafetyCheckCancelReason? cancelReason,  DateTime? escalationQueuedAt,  DateTime? escalationSyncedAt)?  $default,) {final _that = this;
switch (_that) {
case _SafetyCheck() when $default != null:
return $default(_that.id,_that.incidentId,_that.journeyId,_that.uid,_that.status,_that.startedAt,_that.deadline,_that.confirmedAt,_that.timedOutAt,_that.timeoutProcessedAt,_that.escalationReadyAt,_that.cancelledAt,_that.cancelReason,_that.escalationQueuedAt,_that.escalationSyncedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SafetyCheck implements SafetyCheck {
  const _SafetyCheck({required this.id, required this.incidentId, required this.journeyId, required this.uid, required this.status, required this.startedAt, required this.deadline, this.confirmedAt, this.timedOutAt, this.timeoutProcessedAt, this.escalationReadyAt, this.cancelledAt, this.cancelReason, this.escalationQueuedAt, this.escalationSyncedAt});
  factory _SafetyCheck.fromJson(Map<String, dynamic> json) => _$SafetyCheckFromJson(json);

@override final  String id;
@override final  String incidentId;
@override final  String journeyId;
@override final  String uid;
@override final  SafetyCheckStatus status;
/// When it was asked, and when the answer is due (UTC).
@override final  DateTime startedAt;
@override final  DateTime deadline;
@override final  DateTime? confirmedAt;
/// The deadline that passed (UTC), and when the app noticed — later,
/// when the app was suspended meanwhile.
@override final  DateTime? timedOutAt;
@override final  DateTime? timeoutProcessedAt;
@override final  DateTime? escalationReadyAt;
@override final  DateTime? cancelledAt;
@override final  SafetyCheckCancelReason? cancelReason;
/// When the escalation request was written on this phone, and when the
/// server confirmed having it. Apart after an offline stretch.
@override final  DateTime? escalationQueuedAt;
@override final  DateTime? escalationSyncedAt;

/// Create a copy of SafetyCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SafetyCheckCopyWith<_SafetyCheck> get copyWith => __$SafetyCheckCopyWithImpl<_SafetyCheck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SafetyCheckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SafetyCheck&&(identical(other.id, id) || other.id == id)&&(identical(other.incidentId, incidentId) || other.incidentId == incidentId)&&(identical(other.journeyId, journeyId) || other.journeyId == journeyId)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.status, status) || other.status == status)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.deadline, deadline) || other.deadline == deadline)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.timedOutAt, timedOutAt) || other.timedOutAt == timedOutAt)&&(identical(other.timeoutProcessedAt, timeoutProcessedAt) || other.timeoutProcessedAt == timeoutProcessedAt)&&(identical(other.escalationReadyAt, escalationReadyAt) || other.escalationReadyAt == escalationReadyAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancelReason, cancelReason) || other.cancelReason == cancelReason)&&(identical(other.escalationQueuedAt, escalationQueuedAt) || other.escalationQueuedAt == escalationQueuedAt)&&(identical(other.escalationSyncedAt, escalationSyncedAt) || other.escalationSyncedAt == escalationSyncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,incidentId,journeyId,uid,status,startedAt,deadline,confirmedAt,timedOutAt,timeoutProcessedAt,escalationReadyAt,cancelledAt,cancelReason,escalationQueuedAt,escalationSyncedAt);

@override
String toString() {
  return 'SafetyCheck(id: $id, incidentId: $incidentId, journeyId: $journeyId, uid: $uid, status: $status, startedAt: $startedAt, deadline: $deadline, confirmedAt: $confirmedAt, timedOutAt: $timedOutAt, timeoutProcessedAt: $timeoutProcessedAt, escalationReadyAt: $escalationReadyAt, cancelledAt: $cancelledAt, cancelReason: $cancelReason, escalationQueuedAt: $escalationQueuedAt, escalationSyncedAt: $escalationSyncedAt)';
}


}

/// @nodoc
abstract mixin class _$SafetyCheckCopyWith<$Res> implements $SafetyCheckCopyWith<$Res> {
  factory _$SafetyCheckCopyWith(_SafetyCheck value, $Res Function(_SafetyCheck) _then) = __$SafetyCheckCopyWithImpl;
@override @useResult
$Res call({
 String id, String incidentId, String journeyId, String uid, SafetyCheckStatus status, DateTime startedAt, DateTime deadline, DateTime? confirmedAt, DateTime? timedOutAt, DateTime? timeoutProcessedAt, DateTime? escalationReadyAt, DateTime? cancelledAt, SafetyCheckCancelReason? cancelReason, DateTime? escalationQueuedAt, DateTime? escalationSyncedAt
});




}
/// @nodoc
class __$SafetyCheckCopyWithImpl<$Res>
    implements _$SafetyCheckCopyWith<$Res> {
  __$SafetyCheckCopyWithImpl(this._self, this._then);

  final _SafetyCheck _self;
  final $Res Function(_SafetyCheck) _then;

/// Create a copy of SafetyCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? incidentId = null,Object? journeyId = null,Object? uid = null,Object? status = null,Object? startedAt = null,Object? deadline = null,Object? confirmedAt = freezed,Object? timedOutAt = freezed,Object? timeoutProcessedAt = freezed,Object? escalationReadyAt = freezed,Object? cancelledAt = freezed,Object? cancelReason = freezed,Object? escalationQueuedAt = freezed,Object? escalationSyncedAt = freezed,}) {
  return _then(_SafetyCheck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,incidentId: null == incidentId ? _self.incidentId : incidentId // ignore: cast_nullable_to_non_nullable
as String,journeyId: null == journeyId ? _self.journeyId : journeyId // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SafetyCheckStatus,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,deadline: null == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as DateTime,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timedOutAt: freezed == timedOutAt ? _self.timedOutAt : timedOutAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timeoutProcessedAt: freezed == timeoutProcessedAt ? _self.timeoutProcessedAt : timeoutProcessedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalationReadyAt: freezed == escalationReadyAt ? _self.escalationReadyAt : escalationReadyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelReason: freezed == cancelReason ? _self.cancelReason : cancelReason // ignore: cast_nullable_to_non_nullable
as SafetyCheckCancelReason?,escalationQueuedAt: freezed == escalationQueuedAt ? _self.escalationQueuedAt : escalationQueuedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,escalationSyncedAt: freezed == escalationSyncedAt ? _self.escalationSyncedAt : escalationSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
