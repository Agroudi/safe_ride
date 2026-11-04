/// A one-time code for a trusted contact to enter in their own SafeRide.
class ContactInvite {
  const ContactInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// The invite seam: how a trusted contact becomes someone an alert can
/// reach. The backend does the work, because it alone may write a link.
/// `CloudContactInviteRepository` implements it. Throws only `InviteFailure`.
abstract interface class ContactInviteRepository {
  /// A code for the signed-in user's contact [contactId].
  Future<ContactInvite> create(String contactId);

  /// The signed-in user accepts [code]. Returns who invited them.
  Future<String> accept(String code);

  /// The contacts who accepted an invite: contact id → the digits of the
  /// number it was accepted for. A contact whose number changed since no
  /// longer counts.
  Future<Map<String, String>> links();

  /// Fires when a link appears or goes.
  Stream<void> get changes;
}
