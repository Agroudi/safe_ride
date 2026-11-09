import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';

sealed class AcceptConnectionState extends Equatable {
  const AcceptConnectionState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// No invite yet: the person pastes what they were sent.
final class AcceptEntry extends AcceptConnectionState {
  const AcceptEntry();
}

final class AcceptChecking extends AcceptConnectionState {
  const AcceptChecking();
}

/// An account is needed, and none is signed in.
final class AcceptSignedOut extends AcceptConnectionState {
  const AcceptSignedOut();
}

/// The invite is good: this is who sent it, and it waits for a yes.
final class AcceptReady extends AcceptConnectionState {
  const AcceptReady(this.inviterName, {this.submitting = false, this.failure});

  final String inviterName;
  final bool submitting;

  /// Why the last try failed, with the invite still there to try again.
  final ConnectionFailureCode? failure;

  @override
  List<Object?> get props => <Object?>[inviterName, submitting, failure];
}

/// The server confirmed it, on both sides.
final class AcceptDone extends AcceptConnectionState {
  const AcceptDone(this.inviterName);

  final String inviterName;

  @override
  List<Object?> get props => <Object?>[inviterName];
}

final class AcceptFailed extends AcceptConnectionState {
  const AcceptFailed(this.code);

  final ConnectionFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
