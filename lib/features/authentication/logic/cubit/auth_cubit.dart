import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/states/auth_state.dart';

/// Submits the login and registration forms — one per screen. No
/// `BuildContext`, no navigation: the page listens and moves on.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthInitial());

  final AuthRepository _repository;

  Future<void> login({required String email, required String password}) =>
      _submit(() => _repository.login(email: email, password: password));

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) => _submit(
    () => _repository.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
    ),
  );

  /// One submission at a time: a second tap while one is running is dropped.
  Future<void> _submit(Future<UserModel> Function() call) async {
    if (state is AuthSubmitting) return;
    emit(const AuthSubmitting());
    try {
      final UserModel user = await call();
      if (!isClosed) emit(AuthSucceeded(user));
    } on AuthFailure catch (e) {
      if (!isClosed) emit(AuthFailed(e.code));
    }
  }
}
