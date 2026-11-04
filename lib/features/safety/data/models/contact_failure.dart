/// Why a trusted-contacts call failed — the one error the repository throws.
enum ContactFailureCode {
  /// Nobody is signed in, so there is no account to keep contacts under.
  signedOut,

  /// No contact has that id (for this account).
  notFound,

  /// Another contact already has this number.
  duplicatePhone,

  /// The list is full (`FirestoreTrustedContactsRepository.maxContacts`).
  full,

  /// SafeRide's servers could not be reached, and the phone has no copy.
  network,

  /// The contacts could not be read or saved (including a change the
  /// server's rules refused).
  storage,
}

class ContactFailure implements Exception {
  const ContactFailure(this.code);

  final ContactFailureCode code;

  @override
  String toString() => 'ContactFailure(${code.name})';
}
