import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/states/account_state.dart';

/// Loads the signed-in user for the profile, saves profile edits, and signs
/// out; reloads when the repository reports a change (an edit saved on the
/// edit screen shows on the profile beneath it).
///
/// Signing out ends the session only — the onboarding flag, the language and
/// the theme live elsewhere and are never touched here (CLAUDE.md §16).
class AccountCubit extends Cubit<AccountState> {
  AccountCubit(this._repository) : super(const AccountLoading()) {
    _subscription = _repository.changes.listen((_) {
      final AccountState now = state;
      if (now is AccountReady && !now.signingOut) load();
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    try {
      final UserModel? user = await _repository.currentUser();
      if (isClosed) return;
      // No user means the session went away under us: leave like a sign-out.
      emit(user == null ? const AccountSignedOut() : AccountReady(user));
    } on AuthFailure catch (e) {
      if (!isClosed) emit(AccountFailed(e.code));
    }
  }

  Future<void> signOut() async {
    final AccountState current = state;
    final UserModel? user = switch (current) {
      AccountReady(:final UserModel user) => user,
      AccountFailed(:final UserModel? user) => user,
      _ => null,
    };
    if (current is AccountReady && current.signingOut) return;
    if (user != null) emit(AccountReady(user, signingOut: true));
    try {
      await _repository.logout();
      if (!isClosed) emit(const AccountSignedOut());
    } on AuthFailure catch (e) {
      if (!isClosed) emit(AccountFailed(e.code, user: user));
    }
  }

  /// Saves the edit screen's name and phone. Null on success; the code
  /// otherwise, for the page's notice.
  Future<AuthFailureCode?> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    try {
      await _repository.updateProfile(fullName: fullName, phone: phone);
      return null;
    } on AuthFailure catch (e) {
      return e.code;
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
