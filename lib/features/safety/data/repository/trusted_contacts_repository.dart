import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';

/// The trusted-contacts seam. `LocalTrustedContactsRepository` keeps them on
/// the phone; a Firebase implementation replaces it behind this interface —
/// one line in the service locator. Every method throws only
/// `ContactFailure` and works on the signed-in account's contacts.
abstract interface class TrustedContactsRepository {
  /// Alphabetical by name.
  Future<List<TrustedContactModel>> contacts();

  Future<TrustedContactModel?> contact(String id);

  /// Throws `duplicatePhone` or `full`.
  Future<TrustedContactModel> add({
    required String fullName,
    required String phone,
    String? relationship,
  });

  /// Throws `notFound` or `duplicatePhone`.
  Future<TrustedContactModel> update(
    String id, {
    required String fullName,
    required String phone,
    String? relationship,
  });

  Future<void> delete(String id);

  /// Fires after every change, so open screens reload.
  Stream<void> get changes;
}
