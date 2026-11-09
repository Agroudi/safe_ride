import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';

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

  /// Timed out, and its escalation prepared: the record the follow-up and
  /// `EscalationSync` work from. What happened next is [SafetyCheck.stage].
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

/// How a prepared escalation was closed.
enum EscalationResolution {
  /// The user said "I'm okay" after the deadline.
  userSafe,

  /// The journey ended (completed or cancelled) first.
  journeyEnded,
}

/// The escalation lifecycle as one value, derived from a [SafetyCheck] —
/// never stored, so it can never disagree with the record.
///
/// ```
/// incidentDetected ─▶ awaitingUserConfirmation ─▶ confirmedSafe      (final)
///                              │          └─────▶ cancelled          (final)
///                              └─▶ timedOut ─▶ escalationPrepared
///                                                 └─▶ awaitingUserAction
///                                 escalationPrepared / awaitingUserAction
///                                                 └─▶ resolved       (final)
/// ```
///
/// [incidentDetected] belongs to an incident no check exists for yet.
/// **A timeout means no answer**, and preparing an escalation contacts
/// no one.
enum SafetyStage {
  incidentDetected,
  awaitingUserConfirmation,
  confirmedSafe,
  timedOut,

  /// The record is ready; the user has not yet seen what to do next.
  escalationPrepared,

  /// The user has seen it; it stays open until they say they are okay or the
  /// journey ends.
  awaitingUserAction,
  resolved,
  cancelled;

  bool get isFinal =>
      this == confirmedSafe || this == resolved || this == cancelled;
}

/// One "Are you okay?" for one potential incident, kept on the phone. The
/// countdown is the [deadline]: whatever happened to timers meanwhile, the
/// time left is always `deadline - now`.
///
/// After a timeout it is also the incident's **escalation record**: its id is
/// the incident's, so there is only ever one, and it keeps what happened
/// when — never where.
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

    /// What was noticed and how sure detection was, copied when asked, so
    /// the record stands even when the incident has been tidied away. Null in
    /// checks made before Batch 19.
    IncidentType? incidentType,
    IncidentConfidence? incidentConfidence,
    DateTime? incidentDetectedAt,
    DateTime? confirmedAt,

    /// The deadline that passed (UTC), and when the app noticed — later,
    /// when the app was suspended meanwhile.
    DateTime? timedOutAt,
    DateTime? timeoutProcessedAt,
    DateTime? escalationReadyAt,

    /// When the user was first shown what to do after no answer, and when
    /// and how that closed.
    DateTime? presentedAt,
    DateTime? resolvedAt,
    EscalationResolution? resolution,
    DateTime? cancelledAt,
    SafetyCheckCancelReason? cancelReason,

    /// When the escalation request was written on this phone, and when the
    /// server confirmed having it. Apart after an offline stretch.
    DateTime? escalationQueuedAt,
    DateTime? escalationSyncedAt,
  }) = _SafetyCheck;

  const SafetyCheck._();

  factory SafetyCheck.fromJson(Map<String, dynamic> json) =>
      _$SafetyCheckFromJson(json);

  SafetyStage get stage => switch (status) {
    SafetyCheckStatus.pending => SafetyStage.awaitingUserConfirmation,
    SafetyCheckStatus.confirmedSafe => SafetyStage.confirmedSafe,
    SafetyCheckStatus.timedOut => SafetyStage.timedOut,
    SafetyCheckStatus.cancelled => SafetyStage.cancelled,
    SafetyCheckStatus.escalationReady =>
      resolvedAt != null
          ? SafetyStage.resolved
          : presentedAt != null
          ? SafetyStage.awaitingUserAction
          : SafetyStage.escalationPrepared,
  };

  /// An escalation the user has not closed.
  bool get isOpenEscalation =>
      status == SafetyCheckStatus.escalationReady && resolvedAt == null;

  /// Seen, once: later calls change nothing.
  SafetyCheck presented(DateTime at) => stage == SafetyStage.escalationPrepared
      ? copyWith(presentedAt: at.toUtc())
      : this;

  /// Closed, once: a closed or never-opened escalation stays as it is.
  SafetyCheck resolved(EscalationResolution how, DateTime at) =>
      isOpenEscalation
      ? copyWith(resolvedAt: at.toUtc(), resolution: how)
      : this;
}
