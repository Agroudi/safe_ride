import 'package:safe_ride/features/authentication/data/models/user_model.dart';

/// The authentication seam: everything the app asks about who is signed in
/// goes through this interface, never through a storage or network client.
///
/// A Firebase or API implementation replaces `LocalAuthRepository` behind
/// this same interface — one line in the service locator. Every method
/// throws only `AuthFailure`.
abstract interface class AuthRepository {
  /// True when a signed-in session is stored on this device. Answers locally;
  /// it does not ask a server whether the session is still valid.
  Future<bool> hasSession();

  /// The signed-in user, or null when nobody is.
  Future<UserModel?> currentUser();

  /// Creates an account and signs it in. Throws `emailTaken`.
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  });

  /// Signs in. Throws `noAccount` or `wrongPassword`.
  Future<UserModel> login({required String email, required String password});

  /// Changes the signed-in user's name and phone. The email is the account's
  /// key and does not change. Throws `storage` when nobody is signed in.
  Future<UserModel> updateProfile({required String fullName, String? phone});

  /// Ends the session — and nothing else: the accounts, the onboarding flag,
  /// the language and the theme all stay.
  Future<void> logout();

  /// Fires after a sign-in, a sign-out or a profile change.
  Stream<void> get changes;
}
