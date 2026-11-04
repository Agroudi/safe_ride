import 'package:freezed_annotation/freezed_annotation.dart';

part 'safety_check.freezed.dart';
part 'safety_check.g.dart';

/// Where a safety check is. The allowed moves are in [SafetyCheckStatusX];
/// nothing else changes a check's status.
enum SafetyCheckStatus {
  /// Asking "Are you okay?"; the countdown runs to `deadline`.
  pending,

  /// The user answered "I'm safe" before the deadline. Final.
  confirmedSafe,

  /// The deadline passed without an answer. Not a confirmed accident.
  timedOut,

  /// Timed out, and its incident handed over: `EscalationSync` reports it
  /// to the backend.
  escalationReady,

  /// Stopped before an answer: the journey ended or the account signed
  /// out. Final; never escalated.
  cancelled,
}

/// The state machine.
///
/// ```
/// pending ──▶ confirmedSafe            (final)
///    │  └───▶ cancelled                (final)
///    └──────▶ timedOut ──▶ escalationReady
/// ```
extension SafetyCheckStatusX on SafetyCheckStatus {
  static const Map<SafetyCheckStatus, Set<SafetyCheckStatus>> _next =
      <SafetyCheckStatus, Set<SafetyCheckStatus>>{
        SafetyCheckStatus.pending: <SafetyCheckStatus>{
          SafetyCheckStatus.confirmedSafe,
          SafetyCheckStatus.timedOut,
          SafetyCheckStatus.cancelled,
        },
        SafetyCheckStatus.timedOut: <SafetyCheckStatus>{
          SafetyCheckStatus.escalationReady,
        },
      };

  bool canMoveTo(SafetyCheckStatus next) =>
      _next[this]?.contains(next) ?? false;

  /// No answer can change it any more.
  bool get isFinal =>
      this == SafetyCheckStatus.confirmedSafe ||
      this == SafetyCheckStatus.cancelled ||
      this == SafetyCheckStatus.escalationReady;
}

/// Why a check was cancelled.
enum SafetyCheckCancelReason { journeyEnded, signedOut }

/// One "Are you okay?" for one potential incident, kept on the phone. The
/// countdown is the [deadline]: whatever happened to timers meanwhile, the
/// time left is always `deadline - now`.
@freezed
abstract class SafetyCheck with _$SafetyCheck {
  const factory SafetyCheck({
    required String id,
    required String incidentId,
    required String journeyId,
    required String uid,
    required SafetyCheckStatus status,

    /// When it was asked, and when the answer is due (UTC).
    required DateTime startedAt,
    required DateTime deadline,
    DateTime? confirmedAt,

    /// The deadline that passed (UTC), and when the app noticed — later,
    /// when the app was suspended meanwhile.
    DateTime? timedOutAt,
    DateTime? timeoutProcessedAt,
    DateTime? escalationReadyAt,
    DateTime? cancelledAt,
    SafetyCheckCancelReason? cancelReason,

    /// When the escalation request was written on this phone, and when the
    /// server confirmed having it. Apart after an offline stretch.
    DateTime? escalationQueuedAt,
    DateTime? escalationSyncedAt,
  }) = _SafetyCheck;

  factory SafetyCheck.fromJson(Map<String, dynamic> json) =>
      _$SafetyCheckFromJson(json);
}
