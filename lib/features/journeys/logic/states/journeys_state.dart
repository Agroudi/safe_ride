import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// The account's journeys and who it is — home and My Journeys.
sealed class JourneysState extends Equatable {
  const JourneysState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class JourneysLoading extends JourneysState {
  const JourneysLoading();
}

final class JourneysReady extends JourneysState {
  const JourneysReady({required this.journeys, this.firstName});

  /// Newest first; may be empty.
  final List<JourneyModel> journeys;

  /// Null when the account has no usable name: greet without one.
  final String? firstName;

  @override
  List<Object?> get props => <Object?>[journeys, firstName];
}

/// The journeys could not be read; the screen still greets [firstName].
final class JourneysFailed extends JourneysState {
  const JourneysFailed(this.code, {this.firstName});

  final JourneyFailureCode code;
  final String? firstName;

  @override
  List<Object?> get props => <Object?>[code, firstName];
}
