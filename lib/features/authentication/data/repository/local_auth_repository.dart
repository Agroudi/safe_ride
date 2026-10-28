import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/local_account_model.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/data/repository/password_hasher.dart';

/// [AuthRepository] for the MVP: demo accounts kept on **this device only**.
///
/// ⚠️ **Local only — this is not production authentication.** No server
/// creates, verifies or protects these accounts: they exist on one phone,
/// are lost with the app's data, and an email is never confirmed. Passwords
/// are stored only as a salted PBKDF2 hash (`PasswordHasher`), never in
/// plaintext, and a password is held in memory only for the call.
///
/// Accounts and the session are secrets, so they live in
/// `flutter_secure_storage` (Keystore / Keychain) — never in
/// shared_preferences:
/// - `auth.accounts`: a JSON map of email → `LocalAccountModel`;
/// - `auth.session`: the signed-in account's email.
///
/// Also the app's [SessionReader]: other features learn who is signed in
/// from it without importing this feature.
class LocalAuthRepository implements AuthRepository, SessionReader {
  LocalAuthRepository(
    this._storage, {
    PasswordHasher hasher = const PasswordHasher(),
  }) : _hasher = hasher;

  final FlutterSecureStorage _storage;
  final PasswordHasher _hasher;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  static const String _sessionKey = 'auth.session';
  static const String _accountsKey = 'auth.accounts';

  /// The one form of an email the repository compares.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  @override
  Future<bool> hasSession() async => await currentUser() != null;

  @override
  Future<UserModel?> currentUser() => _guard(() async {
    final String? email = await _storage.read(key: _sessionKey);
    if (email == null || email.isEmpty) return null;
    return (await _accounts())[email]?.user;
  });

  /// The account's email is its id: journeys and other per-account data are
  /// stored under it.
  @override
  Future<SessionUser?> signedInUser() async {
    try {
      final UserModel? user = await currentUser();
      return user == null
          ? null
          : SessionUser(id: user.email, fullName: user.fullName);
    } on AuthFailure {
      return null;
    }
  }

  @override
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) => _guard(() async {
    final String key = normalizeEmail(email);
    final Map<String, LocalAccountModel> accounts = await _accounts();
    if (accounts.containsKey(key)) {
      throw const AuthFailure(AuthFailureCode.emailTaken);
    }
    final List<int> salt = _hasher.newSalt();
    final String? number = phone?.trim();
    final UserModel user = UserModel(
      fullName: fullName.trim().replaceAll(RegExp(r'\s+'), ' '),
      email: key,
      phone: number == null || number.isEmpty ? null : number,
      createdAt: DateTime.now().toUtc(),
    );
    accounts[key] = LocalAccountModel(
      user: user,
      salt: base64Encode(salt),
      hash: base64Encode(await _hasher.derive(password, salt)),
      iterations: _hasher.iterations,
    );
    await _storage.write(key: _accountsKey, value: _encode(accounts));
    await _storage.write(key: _sessionKey, value: key);
    _changes.add(null);
    return user;
  });

  @override
  Future<UserModel> login({required String email, required String password}) =>
      _guard(() async {
        final String key = normalizeEmail(email);
        final LocalAccountModel? account = (await _accounts())[key];
        if (account == null) {
          throw const AuthFailure(AuthFailureCode.noAccount);
        }
        final List<int> hash = await _hasher.derive(
          password,
          base64Decode(account.salt),
          rounds: account.iterations,
        );
        if (!PasswordHasher.same(hash, base64Decode(account.hash))) {
          throw const AuthFailure(AuthFailureCode.wrongPassword);
        }
        await _storage.write(key: _sessionKey, value: key);
        _changes.add(null);
        return account.user;
      });

  @override
  Future<UserModel> updateProfile({required String fullName, String? phone}) =>
      _guard(() async {
        final String? email = await _storage.read(key: _sessionKey);
        final Map<String, LocalAccountModel> accounts = await _accounts();
        final LocalAccountModel? account = email == null
            ? null
            : accounts[email];
        if (account == null) {
          throw const AuthFailure(AuthFailureCode.storage);
        }
        final String? number = phone?.trim();
        final UserModel user = account.user.copyWith(
          fullName: fullName.trim().replaceAll(RegExp(r'\s+'), ' '),
          phone: number == null || number.isEmpty ? null : number,
        );
        accounts[email!] = account.copyWith(user: user);
        await _storage.write(key: _accountsKey, value: _encode(accounts));
        _changes.add(null);
        return user;
      });

  @override
  Future<void> logout() => _guard(() async {
    await _storage.delete(key: _sessionKey);
    _changes.add(null);
  });

  Future<Map<String, LocalAccountModel>> _accounts() async {
    final String? raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return <String, LocalAccountModel>{};
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return json.map(
      (String email, dynamic account) => MapEntry<String, LocalAccountModel>(
        email,
        LocalAccountModel.fromJson(account as Map<String, dynamic>),
      ),
    );
  }

  static String _encode(Map<String, LocalAccountModel> accounts) => jsonEncode(
    accounts.map(
      (String email, LocalAccountModel account) =>
          MapEntry<String, dynamic>(email, account.toJson()),
    ),
  );

  /// Lets an [AuthFailure] through and turns anything else — a Keystore
  /// error, a corrupt record — into `storage`.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthFailure {
      rethrow;
    } on Object {
      throw const AuthFailure(AuthFailureCode.storage);
    }
  }
}
