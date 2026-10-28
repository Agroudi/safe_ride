/// Why an authentication call failed — the one error type `AuthRepository`
/// throws, so a cubit branches on [AuthFailure.code] and never sees a storage
/// exception.
enum AuthFailureCode {
  /// Register: an account with this email already exists.
  emailTaken,

  /// Login: no account has this email.
  noAccount,

  /// Login: the password does not match.
  wrongPassword,

  /// The device's storage could not be read or written.
  storage,

  /// Anything else.
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}
