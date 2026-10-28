import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// One journey's details screen.
sealed class JourneyState extends Equatable {
  const JourneyState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class JourneyLoading extends JourneyState {
  const JourneyLoading();
}

final class JourneyReady extends JourneyState {
  const JourneyReady(this.journey, {this.busy = false});

  final JourneyModel journey;

  /// A status change is being saved; both actions are locked.
  final bool busy;

  @override
  List<Object?> get props => <Object?>[journey, busy];
}

/// No journey with that id on this account (deleted data, a stale link).
final class JourneyMissing extends JourneyState {
  const JourneyMissing();
}

/// Loading or a status change failed; [journey] is kept when known.
final class JourneyFailed extends JourneyState {
  const JourneyFailed(this.code, {this.journey});

  final JourneyFailureCode code;
  final JourneyModel? journey;

  @override
  List<Object?> get props => <Object?>[code, journey];
}
