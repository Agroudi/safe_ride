import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';

/// The settings screen's account: who is signed in, and signing out.
sealed class AccountState extends Equatable {
  const AccountState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class AccountLoading extends AccountState {
  const AccountLoading();
}

final class AccountReady extends AccountState {
  const AccountReady(this.user, {this.signingOut = false});

  final UserModel user;

  /// Sign-out is running; the button is busy.
  final bool signingOut;

  @override
  List<Object?> get props => <Object?>[user, signingOut];
}

/// The session is gone — the page leaves for welcome.
final class AccountSignedOut extends AccountState {
  const AccountSignedOut();
}

/// Loading or signing out failed. [user] is kept when it was known, so the
/// screen still shows who is signed in.
final class AccountFailed extends AccountState {
  const AccountFailed(this.code, {this.user});

  final AuthFailureCode code;
  final UserModel? user;

  @override
  List<Object?> get props => <Object?>[code, user];
}
