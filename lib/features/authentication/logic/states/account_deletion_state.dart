import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';

sealed class AccountDeletionState extends Equatable {
  const AccountDeletionState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class DeletionIdle extends AccountDeletionState {
  const DeletionIdle();
}

final class DeletionBusy extends AccountDeletionState {
  const DeletionBusy();
}

/// The account no longer exists.
final class DeletionDone extends AccountDeletionState {
  const DeletionDone();
}

final class DeletionFailed extends AccountDeletionState {
  const DeletionFailed(this.code);

  final AuthFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
