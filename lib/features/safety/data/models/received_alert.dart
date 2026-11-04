import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/core/firebase/timestamp_converter.dart';

part 'received_alert.freezed.dart';
part 'received_alert.g.dart';

/// An alert this user received as someone's trusted contact
/// (`users/{uid}/receivedAlerts/{id}`, written by the backend). It holds what
/// they were authorised to see — who, when, what kind of event — and no
/// location.
@freezed
abstract class ReceivedAlert with _$ReceivedAlert {
  const factory ReceivedAlert({
    required String id,
    required String fromName,

    /// `suddenDeceleration` or `prolongedStop`.
    required String type,

    /// When the safety check went unanswered (UTC).
    @TimestampConverter() required DateTime eventAt,

    /// The number on their profile, if they gave one. Unverified.
    String? fromPhone,
  }) = _ReceivedAlert;

  factory ReceivedAlert.fromJson(Map<String, dynamic> json) =>
      _$ReceivedAlertFromJson(json);
}
