import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

/// The signed-in account's connections to other accounts, and its invites. It
/// throws `ConnectionFailure`.
///
/// Everything that changes who is connected waits for the server and fails
/// offline: nothing here is queued, and nothing reads as done until it is. A
/// failure that was only a lost answer is found out and is not a failure.
abstract interface class ConnectionRepository {
  /// Fires when a connection or an invite changes, here or on the other phone.
  Stream<void> get changes;

  /// Whether what was last read is the phone's copy, not confirmed by the
  /// server: the other side may have ended something since.
  bool get mayBeStale;

  /// Every connection of this account, ended ones too, by name.
  Future<List<ConnectionModel>> connections();

  /// This account's invites that nobody accepted, newest first.
  Future<List<ConnectionInviteModel>> invites();

  Future<ConnectionInviteModel> createInvite();

  Future<void> cancelInvite(String token);

  /// Who is inviting: read from the server, so never a stale answer.
  Future<ConnectionInviteModel> preview(String token);

  /// Makes the connection, on both sides, or throws having made nothing.
  Future<ConnectionModel> accept(String token);

  /// Ends the connection for both people.
  Future<void> revoke(String contactUid);

  /// Null or blank takes the nickname away.
  Future<void> rename(String contactUid, String? nickname);

  /// Removes an ended connection from this account's list.
  Future<void> clear(String contactUid);
}
