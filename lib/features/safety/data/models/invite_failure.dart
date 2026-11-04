/// Why an invite could not be made or used — the one error the invite
/// repository throws.
enum InviteFailureCode {
  /// No invite has this code.
  invalidCode,

  /// Expired, already used, or its contact changed: ask for a new one.
  noLongerValid,

  /// The user's own invite: it is for the person it was made for.
  ownInvite,

  /// The phone has no connection.
  network,

  /// SafeRide's server did not answer (or is not set up yet).
  unavailable,
}

class InviteFailure implements Exception {
  const InviteFailure(this.code);

  final InviteFailureCode code;

  @override
  String toString() => 'InviteFailure(${code.name})';
}
