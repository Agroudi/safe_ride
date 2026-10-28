import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_state.dart';

/// One journey: loads it, applies the user's edits and status changes, and
/// reloads whenever the repository reports a change — so an edit saved on
/// the edit screen is on the details screen beneath it. There is no
/// automatic transition: nothing tracks the journey.
class JourneyCubit extends Cubit<JourneyState> {
  JourneyCubit(this._repository) : super(const JourneyLoading()) {
    _subscription = _repository.changes.listen((_) {
      final String? id = _id;
      final JourneyState now = state;
      // Mid-change the cubit emits the result itself.
      if (id != null && !(now is JourneyReady && now.busy)) load(id);
    });
  }

  final JourneyRepository _repository;
  late final StreamSubscription<void> _subscription;
  String? _id;

  Future<void> load(String id) async {
    _id = id;
    try {
      final JourneyModel? journey = await _repository.journey(id);
      if (isClosed) return;
      emit(journey == null ? const JourneyMissing() : JourneyReady(journey));
    } on JourneyFailure catch (e) {
      if (!isClosed) emit(JourneyFailed(e.code));
    }
  }

  Future<void> complete() => _settle(_repository.complete);

  Future<void> cancel() => _settle(_repository.cancel);

  /// Saves the edit screen's places and departure (planned journeys only).
  Future<void> update({
    required String origin,
    required String destination,
    required DateTime departsAt,
  }) => _settle(
    (String id) => _repository.update(
      id,
      origin: origin,
      destination: destination,
      departsAt: departsAt,
    ),
  );

  Future<void> _settle(Future<JourneyModel> Function(String id) change) async {
    final JourneyState current = state;
    final JourneyModel? journey = switch (current) {
      JourneyReady(:final JourneyModel journey, busy: false) => journey,
      JourneyFailed(:final JourneyModel? journey) => journey,
      _ => null,
    };
    if (journey == null) return;
    emit(JourneyReady(journey, busy: true));
    try {
      final JourneyModel settled = await change(journey.id);
      if (!isClosed) emit(JourneyReady(settled));
    } on JourneyFailure catch (e) {
      if (!isClosed) emit(JourneyFailed(e.code, journey: journey));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
