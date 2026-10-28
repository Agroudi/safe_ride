import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/local_auth_repository.dart';
import 'package:safe_ride/features/authentication/data/repository/password_hasher.dart';

/// Few rounds: the tests are about behaviour, not cost.
const PasswordHasher _fast = PasswordHasher(iterations: 64);

/// A repository over a secure store that already holds [stored].
LocalAuthRepository _repository([
  Map<String, String> stored = const <String, String>{},
]) {
  FlutterSecureStorage.setMockInitialValues(Map<String, String>.of(stored));
  return LocalAuthRepository(FlutterSecureStorage(), hasher: _fast);
}

/// Everything the store holds, as one string.
Future<String> _dump() async =>
    jsonEncode(await const FlutterSecureStorage().readAll());

Matcher _fails(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((AuthFailure f) => f.code, 'code', code));

Future<UserModel> _register(
  LocalAuthRepository repository, {
  String email = 'Sara@Example.com ',
  String password = 'Secret123',
  String? phone,
}) => repository.register(
  fullName: '  Sara   Ahmed ',
  email: email,
  password: password,
  phone: phone,
);

void main() {
  test('an empty store has no session and no user', () async {
    final LocalAuthRepository repository = _repository();
    expect(await repository.hasSession(), isFalse);
    expect(await repository.currentUser(), isNull);
  });

  test(
    'register signs in, with a tidied name and a normalized email',
    () async {
      final LocalAuthRepository repository = _repository();
      final UserModel user = await _register(repository, phone: ' ');

      expect(user.fullName, 'Sara Ahmed');
      expect(user.email, 'sara@example.com');
      expect(user.phone, isNull);
      expect(await repository.hasSession(), isTrue);
      expect(await repository.currentUser(), user);
    },
  );

  test('the password is never stored, only a salted hash', () async {
    await _register(_repository(), password: 'Secret123');
    final String stored = await _dump();

    expect(stored, isNot(contains('Secret123')));
    expect(stored, contains('"hash'));
    expect(stored, contains('"salt'));
  });

  test('two accounts with one password get different hashes', () async {
    final LocalAuthRepository repository = _repository();
    await _register(repository, email: 'a@example.com');
    await _register(repository, email: 'b@example.com');
    final Map<String, dynamic> accounts =
        jsonDecode(
              (await const FlutterSecureStorage().read(key: 'auth.accounts'))!,
            )
            as Map<String, dynamic>;

    expect(
      (accounts['a@example.com'] as Map<String, dynamic>)['hash'],
      isNot((accounts['b@example.com'] as Map<String, dynamic>)['hash']),
    );
  });

  test('the same email cannot register twice, in any case', () async {
    final LocalAuthRepository repository = _repository();
    await _register(repository);

    expect(
      _register(repository, email: 'SARA@example.COM'),
      _fails(AuthFailureCode.emailTaken),
    );
  });

  test('login checks the password and starts a session', () async {
    final LocalAuthRepository repository = _repository();
    await _register(repository);
    await repository.logout();

    final UserModel user = await repository.login(
      email: ' SARA@example.com',
      password: 'Secret123',
    );
    expect(user.email, 'sara@example.com');
    expect(await repository.hasSession(), isTrue);
  });

  test('a wrong password and an unknown email fail differently', () async {
    final LocalAuthRepository repository = _repository();
    await _register(repository);
    await repository.logout();

    expect(
      repository.login(email: 'sara@example.com', password: 'secret123'),
      _fails(AuthFailureCode.wrongPassword),
    );
    expect(
      repository.login(email: 'nobody@example.com', password: 'Secret123'),
      _fails(AuthFailureCode.noAccount),
    );
    expect(await repository.hasSession(), isFalse);
  });

  test('logout ends the session and keeps the account', () async {
    final LocalAuthRepository repository = _repository();
    await _register(repository);

    await repository.logout();

    expect(await repository.hasSession(), isFalse);
    expect(await repository.currentUser(), isNull);
    await repository.login(email: 'sara@example.com', password: 'Secret123');
  });

  test('a profile edit tidies the name and keeps the sign-in', () async {
    final LocalAuthRepository repository = _repository();
    await _register(repository, phone: '+966 50 000 0000');

    final UserModel user = await repository.updateProfile(
      fullName: '  Sara   Al-Harbi ',
      phone: ' ',
    );

    expect(user.fullName, 'Sara Al-Harbi');
    expect(user.phone, isNull);
    expect(user.email, 'sara@example.com');
    expect(await repository.currentUser(), user);
    await repository.logout();
    final UserModel again = await repository.login(
      email: 'sara@example.com',
      password: 'Secret123',
    );
    expect(again.fullName, 'Sara Al-Harbi');
  });

  test('a profile edit with nobody signed in fails', () async {
    expect(
      _repository().updateProfile(fullName: 'Sara'),
      _fails(AuthFailureCode.storage),
    );
  });

  test('sign-in, edits and sign-out are announced on changes', () async {
    final LocalAuthRepository repository = _repository();
    int changes = 0;
    final StreamSubscription<void> listening = repository.changes.listen(
      (_) => changes++,
    );

    await _register(repository);
    await repository.updateProfile(fullName: 'Sara Ahmed');
    await repository.logout();
    await repository.login(email: 'sara@example.com', password: 'Secret123');
    await Future<void>.delayed(Duration.zero);

    expect(changes, 4);
    await listening.cancel();
  });

  // A session naming an account that is gone (cleared data, an older build)
  // must not open home.
  test('a session without its account is not a session', () async {
    final LocalAuthRepository repository = _repository(<String, String>{
      'auth.session': 'ghost@example.com',
    });

    expect(await repository.hasSession(), isFalse);
  });

  test('a corrupt store is a storage failure, never a crash', () async {
    final LocalAuthRepository repository = _repository(<String, String>{
      'auth.session': 'sara@example.com',
      'auth.accounts': '{not json',
    });

    expect(repository.currentUser(), _fails(AuthFailureCode.storage));
    expect(
      repository.login(email: 'sara@example.com', password: 'x'),
      _fails(AuthFailureCode.storage),
    );
  });

  // The keys are the storage format: renaming one signs everyone out.
  test('the store keys are auth.accounts and auth.session', () async {
    await _register(_repository());
    final Map<String, String> all = await const FlutterSecureStorage()
        .readAll();

    expect(
      all.keys,
      unorderedEquals(<String>['auth.accounts', 'auth.session']),
    );
    expect(all['auth.session'], 'sara@example.com');
  });

  group('PasswordHasher', () {
    test('is PBKDF2-HMAC-SHA256 (RFC 7914 test vector)', () async {
      // P = "passwd", S = "salt", c = 1, dkLen = 32.
      final List<int> key = await const PasswordHasher(
        iterations: 1,
      ).derive('passwd', utf8.encode('salt'));
      expect(
        key.map((int b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );
    });

    test('compares in full', () {
      expect(PasswordHasher.same(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
      expect(PasswordHasher.same(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
      expect(PasswordHasher.same(<int>[1, 2], <int>[1, 2, 3]), isFalse);
    });
  });
}
