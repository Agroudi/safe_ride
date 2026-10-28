import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// The review screen's confirmation.
sealed class PlanJourneyState extends Equatable {
  const PlanJourneyState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class PlanJourneyIdle extends PlanJourneyState {
  const PlanJourneyIdle();
}

/// Confirm is busy; a second tap is dropped.
final class PlanJourneySaving extends PlanJourneyState {
  const PlanJourneySaving();
}

final class PlanJourneySaved extends PlanJourneyState {
  const PlanJourneySaved(this.journey);

  final JourneyModel journey;

  @override
  List<Object?> get props => <Object?>[journey];
}

/// Recoverable: the review stays, so Confirm can be tried again.
final class PlanJourneyFailed extends PlanJourneyState {
  const PlanJourneyFailed(this.code);

  final JourneyFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
