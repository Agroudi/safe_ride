import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';

/// One journey's open escalation — a safety check nobody answered that the
/// user has not closed — for the journey screen. Null when there is none.
class OpenEscalationCubit extends Cubit<OpenEscalation?> {
  OpenEscalationCubit(this._escalations) : super(null) {
    _changes = _escalations.changed.listen((_) => _load());
  }

  final EscalationGate _escalations;
  late final StreamSubscription<void> _changes;
  String? _journeyId;
  bool _resolving = false;

  Future<void> watch(String journeyId) {
    _journeyId = journeyId;
    return _load();
  }

  /// "I'm okay": once, however often it is tapped.
  Future<ResolveOutcome?> resolve() async {
    final OpenEscalation? open = state;
    if (open == null || _resolving) return null;
    _resolving = true;
    try {
      return await _escalations.resolveSafe(open.checkId);
    } finally {
      _resolving = false;
      await _load();
    }
  }

  Future<void> _load() async {
    final String? id = _journeyId;
    if (id == null) return;
    final OpenEscalation? open = await _escalations.openFor(id);
    if (!isClosed) emit(open);
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
