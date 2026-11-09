import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';
import 'package:safe_ride/features/safety/logic/states/connections_state.dart';

/// One screen's view of the account's connections and invites. It reloads on
/// every change, so an invite accepted on another phone shows here as it
/// happens. An action answers with why it failed, or null: it is the page that
/// tells the user.
class ConnectionsCubit extends Cubit<ConnectionsState> {
  ConnectionsCubit(this._repository) : super(const ConnectionsState()) {
    _subscription = _repository.changes.listen((_) => load());
  }

  final ConnectionRepository _repository;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    try {
      final List<ConnectionModel> all = await _repository.connections();
      final List<ConnectionInviteModel> invites = await _repository.invites();
      if (isClosed) return;
      emit(
        ConnectionsState(
          phase: ConnectionsPhase.ready,
          connected: all.where((ConnectionModel c) => c.isActive).toList(),
          ended: all.where((ConnectionModel c) => !c.isActive).toList(),
          invites: invites,
          mayBeStale: _repository.mayBeStale,
          busy: state.busy,
        ),
      );
    } on ConnectionFailure catch (e) {
      if (isClosed) return;
      emit(ConnectionsState(phase: ConnectionsPhase.failed, failure: e.code));
    }
  }

  Future<ConnectionFailureCode?> invite() => _act(_repository.createInvite);

  Future<ConnectionFailureCode?> cancel(String token) =>
      _act(() => _repository.cancelInvite(token));

  Future<ConnectionFailureCode?> revoke(String contactUid) =>
      _act(() => _repository.revoke(contactUid));

  Future<ConnectionFailureCode?> rename(String contactUid, String? nickname) =>
      _act(() => _repository.rename(contactUid, nickname));

  Future<ConnectionFailureCode?> clear(String contactUid) =>
      _act(() => _repository.clear(contactUid));

  /// A second tap while the first is on its way does nothing.
  Future<ConnectionFailureCode?> _act(Future<void> Function() step) async {
    if (state.busy) return null;
    emit(state.copyWith(busy: true));
    try {
      await step();
      return null;
    } on ConnectionFailure catch (e) {
      return e.code;
    } finally {
      if (!isClosed) emit(state.copyWith(busy: false));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
