import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/states/plan_journey_state.dart';

/// Saves a reviewed journey — the review screen's Confirm. Nothing is stored
/// before it: the plan screen only collects the places and the departure.
class PlanJourneyCubit extends Cubit<PlanJourneyState> {
  PlanJourneyCubit(this._repository) : super(const PlanJourneyIdle());

  final JourneyRepository _repository;

  Future<void> confirm(JourneyDraft draft) async {
    if (state is PlanJourneySaving || state is PlanJourneySaved) return;
    emit(const PlanJourneySaving());
    try {
      final JourneyModel journey = await _repository.plan(
        origin: draft.origin,
        destination: draft.destination,
        departsAt: draft.departsAt,
      );
      if (!isClosed) emit(PlanJourneySaved(journey));
    } on JourneyFailure catch (e) {
      if (!isClosed) emit(PlanJourneyFailed(e.code));
    }
  }
}
