import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_links.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';
import 'package:safe_ride/features/safety/logic/states/accept_connection_state.dart';

/// Opening an invite and answering it. Only the server's confirmation becomes
/// [AcceptDone]: a failure here, of any kind, has connected nobody.
class AcceptConnectionCubit extends Cubit<AcceptConnectionState> {
  AcceptConnectionCubit(this._repository) : super(const AcceptChecking());

  final ConnectionRepository _repository;
  String? _token;

  /// [token] comes from the link; with none the person pastes it.
  Future<void> open(String? token) async {
    if (token == null) {
      emit(const AcceptEntry());
      return;
    }
    _token = token;
    emit(const AcceptChecking());
    try {
      final ConnectionInviteModel invite = await _repository.preview(token);
      if (!isClosed) emit(AcceptReady(invite.inviterName));
    } on ConnectionFailure catch (e) {
      if (!isClosed) emit(_failed(e.code));
    }
  }

  /// What the person pasted: the link, its message, or the token.
  Future<void> paste(String text) async {
    final String? token = ConnectionLinks.tokenIn(text);
    if (token == null) {
      emit(const AcceptFailed(ConnectionFailureCode.invalid));
      return;
    }
    await open(token);
  }

  void startOver() {
    _token = null;
    emit(const AcceptEntry());
  }

  /// Checks the same invite again, after a lost connection.
  Future<void> retry() => open(_token);

  Future<void> accept() async {
    final AcceptConnectionState now = state;
    final String? token = _token;
    if (now is! AcceptReady || now.submitting || token == null) return;
    emit(AcceptReady(now.inviterName, submitting: true));
    try {
      await _repository.accept(token);
      if (!isClosed) emit(AcceptDone(now.inviterName));
    } on ConnectionFailure catch (e) {
      if (isClosed) return;
      // Worth another try only when nothing is known to be wrong with it.
      emit(
        e.code == ConnectionFailureCode.offline
            ? AcceptReady(now.inviterName, failure: e.code)
            : _failed(e.code),
      );
    }
  }

  AcceptConnectionState _failed(ConnectionFailureCode code) =>
      code == ConnectionFailureCode.signedOut
      ? const AcceptSignedOut()
      : AcceptFailed(code);
}
