import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';

/// Loads the signed-in account's journeys and first name, and reloads after
/// every change the repository reports — so home's "recent journeys" is
/// current the moment a plan is confirmed. One per screen.
class JourneysCubit extends Cubit<JourneysState> {
  JourneysCubit(this._repository, this._session)
    : super(const JourneysLoading()) {
    _subscription = _repository.changes.listen((_) => load());
    _sessionChanges = _session.changes.listen((_) => load());
  }

  final JourneyRepository _repository;
  final SessionReader _session;
  late final StreamSubscription<void> _subscription;

  /// A renamed account greets by its new name at once.
  late final StreamSubscription<void> _sessionChanges;

  Future<void> load() async {
    final String? firstName = (await _session.signedInUser())?.firstName;
    try {
      final List<JourneyModel> all = await _repository.journeys();
      if (!isClosed) emit(JourneysReady(journeys: all, firstName: firstName));
    } on JourneyFailure catch (e) {
      if (!isClosed) emit(JourneysFailed(e.code, firstName: firstName));
    }
  }

  /// Cancels a planned journey from a list. The list reloads through
  /// [JourneyRepository.changes]; the answer is for the page's notice: null
  /// on success.
  Future<JourneyFailureCode?> cancel(String id) async {
    try {
      await _repository.cancel(id);
      return null;
    } on JourneyFailure catch (e) {
      return e.code;
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _sessionChanges.cancel();
    return super.close();
  }
}
