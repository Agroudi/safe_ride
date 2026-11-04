import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';

/// The safety-check prompt's view of [SafetyCheckService]: the check to
/// show, and the user's answer. The countdown itself is the check's
/// deadline, read through [now] — never counted here.
class SafetyCheckCubit extends Cubit<SafetyCheckState> {
  SafetyCheckCubit(this._service, this._escalations)
    : super(SafetyCheckState(_service.current)) {
    _changes = _service.changes.listen(
      (SafetyCheck? check) => emit(SafetyCheckState(check)),
    );
  }

  final SafetyCheckService _service;
  final EscalationSync _escalations;
  late final StreamSubscription<SafetyCheck?> _changes;

  DateTime now() => _service.now();

  /// App start, back to the foreground: pick up an overdue or running check,
  /// and report what has not reached the server.
  Future<void> recover() async {
    await _service.recover();
    await _escalations.flush();
  }

  /// The app left the screen: the question moves to a notification.
  Future<void> hidden() => _service.foregroundChanged();

  /// "I'm safe" — once: taps while it is being recorded do nothing.
  Future<ConfirmOutcome?> confirm() async {
    final SafetyCheck? check = state.check;
    if (check == null || state.confirming) return null;
    emit(SafetyCheckState(check, confirming: true));
    final ConfirmOutcome outcome = await _service.confirm(check.id);
    if (!isClosed && state.confirming) {
      emit(SafetyCheckState(_service.current));
    }
    return outcome;
  }

  /// Closes the "no answer" note.
  void acknowledge() => _service.acknowledge();

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}

/// [check] is null when there is nothing to ask.
final class SafetyCheckState extends Equatable {
  const SafetyCheckState(this.check, {this.confirming = false});

  final SafetyCheck? check;
  final bool confirming;

  @override
  List<Object?> get props => <Object?>[check, confirming];
}
