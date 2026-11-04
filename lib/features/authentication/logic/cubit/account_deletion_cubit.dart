import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/states/account_deletion_state.dart';

/// The delete-account screen. Once only: taps while it runs are ignored.
class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this._repository) : super(const DeletionIdle());

  final AuthRepository _repository;

  /// True when the account is gone. The session ending closes this screen
  /// while it runs, so the answer comes back here, not only as a state.
  Future<bool> delete(String password) async {
    if (state is DeletionBusy) return false;
    emit(const DeletionBusy());
    try {
      await _repository.deleteAccount(password: password);
      if (!isClosed) emit(const DeletionDone());
      return true;
    } on AuthFailure catch (e) {
      if (!isClosed) emit(DeletionFailed(e.code));
      return false;
    }
  }
}
