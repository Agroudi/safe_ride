/// Why an authentication call failed — the one error type `AuthRepository`
/// throws, so a cubit branches on [AuthFailure.code] and never sees a
/// Firebase exception.
enum AuthFailureCode {
  /// Register: an account with this email already exists.
  emailTaken,

  /// Login: the email or the password is wrong. Firebase does not say which
  /// — telling them apart would reveal which emails have accounts.
  invalidCredentials,

  /// The server rejected the email's form.
  invalidEmail,

  /// Register: the server rejected the password as too weak.
  weakPassword,

  /// Too many attempts from this phone; Firebase asks to wait.
  tooManyRequests,

  /// The server could not be reached.
  network,

  /// The account was switched off by the project's administrator.
  disabled,

  /// The profile could not be read or saved.
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
