/// Why a trusted-contacts call failed — the one error the repository throws.
enum ContactFailureCode {
  /// Nobody is signed in, so there is no account to keep contacts under.
  signedOut,

  /// No contact has that id (for this account).
  notFound,

  /// Another contact already has this number.
  duplicatePhone,

  /// The list is full (`LocalTrustedContactsRepository.maxContacts`).
  full,

  /// The device's storage could not be read or written.
  storage,
}

class ContactFailure implements Exception {
  const ContactFailure(this.code);

  final ContactFailureCode code;

  @override
  String toString() => 'ContactFailure(${code.name})';
}
