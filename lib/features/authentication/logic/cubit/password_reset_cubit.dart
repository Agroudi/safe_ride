import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/states/password_reset_state.dart';

/// Sends the password-reset email for the forgot-password screen. A second
/// tap while one is sending is dropped.
class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._repository) : super(const PasswordResetIdle());

  final AuthRepository _repository;

  Future<void> send({
    required String email,
    required String languageCode,
  }) async {
    if (state is PasswordResetSending) return;
    emit(const PasswordResetSending());
    try {
      await _repository.sendPasswordReset(
        email: email,
        languageCode: languageCode,
      );
      if (!isClosed) emit(const PasswordResetSent());
    } on AuthFailure catch (e) {
      if (!isClosed) emit(PasswordResetFailed(e.code));
    }
  }
}
