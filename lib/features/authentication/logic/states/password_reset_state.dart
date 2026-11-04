import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';

/// Asking Firebase for a password-reset email.
sealed class PasswordResetState extends Equatable {
  const PasswordResetState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class PasswordResetIdle extends PasswordResetState {
  const PasswordResetIdle();
}

final class PasswordResetSending extends PasswordResetState {
  const PasswordResetSending();
}

/// Sent — or no account has the email; the screen does not say which.
final class PasswordResetSent extends PasswordResetState {
  const PasswordResetSent();
}

final class PasswordResetFailed extends PasswordResetState {
  const PasswordResetFailed(this.code);

  final AuthFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}
