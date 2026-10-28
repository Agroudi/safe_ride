import 'package:equatable/equatable.dart';

/// Where the app opens once startup has decided.
enum StartupDestination { onboarding, welcome, home }

/// The splash's decision: still working, ready with a destination, or failed.
sealed class StartupState extends Equatable {
  const StartupState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class StartupLoading extends StartupState {
  const StartupLoading();
}

final class StartupReady extends StartupState {
  const StartupReady(this.destination);

  final StartupDestination destination;

  @override
  List<Object?> get props => <Object?>[destination];
}

/// The session check threw or timed out. The splash offers a retry rather
/// than guessing a destination — guessing "welcome" would look like a sign-out.
final class StartupFailed extends StartupState {
  const StartupFailed();
}
