import 'package:safe_ride/features/authentication/data/models/user_model.dart';

/// The authentication seam: everything the app asks about who is signed in
/// goes through this interface, never through a storage or network client.
///
/// `FirebaseAuthRepository` implements it today; another backend would be one
/// more implementation, chosen in the service locator. Every method throws
/// only `AuthFailure`.
abstract interface class AuthRepository {
  /// True when a signed-in session is kept on this device. Answers from the
  /// phone; it does not ask the server whether the session is still valid,
  /// so it works offline.
  Future<bool> hasSession();

  /// The signed-in user, or null when nobody is.
  Future<UserModel?> currentUser();

  /// Creates an account, signs it in and saves its profile. [languageCode]
  /// is the language the app shows, kept with the profile. Throws
  /// `emailTaken`, `weakPassword`, `invalidEmail`.
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    required String languageCode,
    String? phone,
  });

  /// Signs in. Throws `invalidCredentials`.
  Future<UserModel> login({required String email, required String password});

  /// Sends a password-reset link, written in [languageCode]. Succeeds
  /// whether or not an account has the email — saying otherwise would tell
  /// anyone which emails have accounts.
  Future<void> sendPasswordReset({
    required String email,
    required String languageCode,
  });

  /// Changes the signed-in user's name and phone. The email does not change.
  /// Throws `storage` when nobody is signed in.
  Future<UserModel> updateProfile({required String fullName, String? phone});

  /// Keeps the language the signed-in user chose with their profile, so
  /// anything the server writes for them can use it. Nothing when signed out.
  Future<void> saveLanguage(String languageCode);

  /// Ends the session — and nothing else: the onboarding flag, the language
  /// and the theme all stay on the phone.
  Future<void> logout();

  /// Deletes the account for good: everything it holds in Firestore and on
  /// this phone, then the sign-in itself. [password] proves it is the owner,
  /// and Firebase requires a recent sign-in. Needs a connection. Throws
  /// `invalidCredentials` before anything is touched. A failure after that
  /// may leave it half done; calling it again finishes the job.
  Future<void> deleteAccount({required String password});

  /// Fires after a sign-in, a sign-out or a profile change.
  Stream<void> get changes;
}
