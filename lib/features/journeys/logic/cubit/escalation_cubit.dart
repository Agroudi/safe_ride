import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/escalation.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';

/// Where a journey's unanswered safety check stands, as far as is known.
enum EscalationPhase {
  /// Nothing unanswered on this journey.
  none,

  /// The request is on this phone, waiting for a connection.
  waitingForConnection,

  /// The server has the request; the backend has not answered yet.
  waitingForServer,

  /// Nothing can process the request: no backend exists, or it stayed
  /// silent. **Nobody was alerted**; the record stays on the phone.
  serviceUnavailable,

  /// The backend is sending, or retrying.
  sending,

  /// The provider accepted at least one alert. Not delivered: unknown.
  accepted,

  /// Every send failed.
  failed,

  /// Nobody can receive an alert.
  noRecipients,

  /// The backend refused the request; nobody was alerted.
  rejected,
}

/// The escalation status of one journey, for its screen and for the "no
/// answer" note: the phone's own record until the backend's exists, and
/// only the backend's after that. Without a backend it never says anything
/// but that nobody was alerted. One per screen.
class EscalationCubit extends Cubit<EscalationState> {
  EscalationCubit(
    this._checks,
    this._repository,
    this._sync,
    this._session, {
    DateTime Function()? clock,
    this.serverWait = const Duration(minutes: 2),
  }) : _clock = clock ?? DateTime.now,
       super(const EscalationState(EscalationPhase.none)) {
    _changes = _sync.changes.listen((_) => _load());
  }

  /// A backend silent for this long after the server took the request is
  /// said to be unavailable: "waiting" must not read as "working".
  final Duration serverWait;

  final SafetyCheckRepository _checks;
  final EscalationRepository _repository;
  final EscalationSync _sync;
  final SessionReader _session;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _changes;
  Timer? _silence;
  StreamSubscription<Escalation?>? _record;
  String? _journeyId;
  String? _watching;
  SafetyCheck? _check;
  Escalation? _escalation;

  Future<void> watch(String journeyId) {
    _journeyId = journeyId;
    return _load();
  }

  Future<void> _load() async {
    final String? journeyId = _journeyId;
    final String? uid = (await _session.signedInUser())?.id;
    if (journeyId == null || uid == null || isClosed) return;
    SafetyCheck? latest;
    for (final SafetyCheck c in await _checks.forUser(uid)) {
      if (c.journeyId == journeyId &&
          c.status == SafetyCheckStatus.escalationReady) {
        latest = c;
      }
    }
    if (isClosed) return;
    _check = latest;
    if (latest != null && latest.id != _watching) {
      _watching = latest.id;
      _escalation = null;
      await _record?.cancel();
      _record = _repository.watch(uid, latest.id).listen(
        (Escalation? e) {
          _escalation = e;
          _emit();
        },
        // Unreadable: what the phone knows still stands.
        onError: (Object _) {},
      );
    }
    _emit();
  }

  void _emit() {
    if (isClosed) return;
    final EscalationPhase phase = _phase();
    _armSilence(phase);
    emit(
      EscalationState(
        phase,
        _escalation,
        _sync.live &&
            (phase == EscalationPhase.waitingForConnection ||
                phase == EscalationPhase.serviceUnavailable),
      ),
    );
  }

  void _armSilence(EscalationPhase phase) {
    _silence?.cancel();
    final DateTime? synced = _check?.escalationSyncedAt;
    if (phase != EscalationPhase.waitingForServer || synced == null) return;
    _silence = Timer(
      synced.add(serverWait).difference(_clock().toUtc()),
      _emit,
    );
  }

  /// Sends what has not reached the server, and looks again.
  Future<void> retry() async {
    await _sync.flush();
    await _load();
  }

  EscalationPhase _phase() {
    final SafetyCheck? check = _check;
    if (check == null) return EscalationPhase.none;
    if (!_sync.live) return EscalationPhase.serviceUnavailable;
    return switch (_escalation?.status) {
      null => _beforeRecord(check.escalationSyncedAt),
      EscalationStatus.dispatching ||
      EscalationStatus.retrying => EscalationPhase.sending,
      EscalationStatus.completed => EscalationPhase.accepted,
      EscalationStatus.failed => EscalationPhase.failed,
      EscalationStatus.noRecipients => EscalationPhase.noRecipients,
      EscalationStatus.rejected => EscalationPhase.rejected,
    };
  }

  /// The backend has said nothing yet.
  EscalationPhase _beforeRecord(DateTime? synced) {
    if (synced == null) return EscalationPhase.waitingForConnection;
    return _clock().toUtc().difference(synced) < serverWait
        ? EscalationPhase.waitingForServer
        : EscalationPhase.serviceUnavailable;
  }

  @override
  Future<void> close() async {
    _silence?.cancel();
    await _changes.cancel();
    await _record?.cancel();
    return super.close();
  }
}

final class EscalationState extends Equatable {
  const EscalationState(this.phase, [this.escalation, this.canRetry = false]);

  final EscalationPhase phase;
  final Escalation? escalation;

  /// Whether trying again could change anything. Never without a backend.
  final bool canRetry;

  @override
  List<Object?> get props => <Object?>[phase, escalation, canRetry];
}
