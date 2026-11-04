import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// The pre-journey checklist screen.
sealed class JourneyStartState extends Equatable {
  const JourneyStartState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class JourneyStartLoading extends JourneyStartState {
  const JourneyStartLoading();
}

/// The journey cannot start from here: missing (`notFound`), already started
/// (`alreadyStarted`), closed (`notPlanned`), or it could not be loaded.
final class JourneyStartUnavailable extends JourneyStartState {
  const JourneyStartUnavailable(this.code);

  final JourneyFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}

/// A planned journey and the items confirmed so far; [starting] while the
/// checklist and the start are being saved — nothing can change then.
final class JourneyStartFilling extends JourneyStartState {
  const JourneyStartFilling(
    this.journey,
    this.confirmed, {
    this.starting = false,
  });

  final JourneyModel journey;
  final Set<String> confirmed;
  final bool starting;

  @override
  List<Object?> get props => <Object?>[journey, confirmed, starting];
}

/// Starting failed in a way the user can retry (connection, storage); the
/// confirmed items are kept.
final class JourneyStartFailed extends JourneyStartState {
  const JourneyStartFailed(this.journey, this.confirmed, this.code);

  final JourneyModel journey;
  final Set<String> confirmed;
  final JourneyFailureCode code;

  @override
  List<Object?> get props => <Object?>[journey, confirmed, code];
}

/// Started; [synced] is false when the phone saved it and the server has not
/// confirmed it yet.
final class JourneyStartStarted extends JourneyStartState {
  const JourneyStartStarted(this.journey, {required this.synced});

  final JourneyModel journey;
  final bool synced;

  @override
  List<Object?> get props => <Object?>[journey, synced];
}
