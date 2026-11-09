/// Why a connection call failed: the one error the repository throws.
enum ConnectionFailureCode {
  /// Nobody is signed in.
  signedOut,

  /// That is not an invite link at all.
  invalid,

  /// Expired, used, cancelled, or its inviter is gone. The server tells these
  /// apart for nobody but the two people involved, on purpose: a stranger with
  /// a token learns nothing from it.
  noLongerValid,

  /// The user's own invite.
  ownInvite,

  /// These two accounts are already connected.
  alreadyConnected,

  /// The profile has no name to connect under.
  profileMissing,

  /// Too many invites waiting, or too many people connected.
  tooMany,

  /// No connection to SafeRide, or none that could confirm the answer. Nothing
  /// is queued, so nothing happens later by itself.
  offline,

  /// The server refused or the invite page is not there: not deployed yet.
  unavailable,
}

class ConnectionFailure implements Exception {
  const ConnectionFailure(this.code);

  final ConnectionFailureCode code;

  @override
  String toString() => 'ConnectionFailure(${code.name})';
}
