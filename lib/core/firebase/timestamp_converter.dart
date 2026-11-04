import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// A Firestore `Timestamp` as a UTC `DateTime`, for the models' `fromJson`.
///
/// A write's `FieldValue.serverTimestamp()` reads as **null** until the
/// server has it — a listener has no option to estimate it — so a pending
/// time reads as now: a journey planned offline still sorts first.
class TimestampConverter implements JsonConverter<DateTime, Object?> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc(),
    DateTime() => value.toUtc(),
    _ => DateTime.now().toUtc(),
  };

  @override
  Object? toJson(DateTime value) => Timestamp.fromDate(value.toUtc());
}

/// [TimestampConverter] for a time that may be absent (`startedAt` before a
/// journey starts): missing stays null. A pending server time also reads as
/// null until the server has it — the field means "known start", not a guess.
class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc(),
    DateTime() => value.toUtc(),
    _ => null,
  };

  @override
  Object? toJson(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value.toUtc());
}
