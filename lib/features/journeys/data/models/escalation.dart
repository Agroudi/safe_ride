import 'package:freezed_annotation/freezed_annotation.dart';

part 'escalation.freezed.dart';
part 'escalation.g.dart';

/// What the backend did about an unanswered safety check. The phone only
/// reads this: no client can write it.
enum EscalationStatus {
  /// Sending to the contacts.
  dispatching,

  /// A send failed for now and will be tried again.
  retrying,

  /// Every send finished, at least one accepted by the provider. That is
  /// not delivery: FCM says nothing about what happened next.
  completed,

  /// No provider took any alert.
  failed,

  /// No contact can receive an alert (none, or none accepted an invite).
  noRecipients,

  /// The backend refused the request; nobody was alerted.
  rejected,
}

/// `users/{uid}/escalations/{safetyCheckId}`, as far as the phone needs it.
@freezed
abstract class Escalation with _$Escalation {
  const factory Escalation({
    required EscalationStatus status,

    /// Why it was rejected, or why there was nobody to alert.
    String? reason,
    @Default(0) int recipients,
    @Default(0) int accepted,
    @Default(0) int failed,
  }) = _Escalation;

  factory Escalation.fromJson(Map<String, dynamic> json) =>
      _$EscalationFromJson(json);
}
