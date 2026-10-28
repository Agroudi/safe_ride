import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';

/// A login or registration form's submission.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// The form is locked and its button busy until the answer lands.
final class AuthSubmitting extends AuthState {
  const AuthSubmitting();
}

final class AuthSucceeded extends AuthState {
  const AuthSucceeded(this.user);

  final UserModel user;

  @override
  List<Object?> get props => <Object?>[user];
}

/// Recoverable: the form keeps what was typed.
final class AuthFailed extends AuthState {
  const AuthFailed(this.code);

  final AuthFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
