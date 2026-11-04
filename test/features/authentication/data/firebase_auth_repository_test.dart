import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/firebase_auth_repository.dart';

Matcher _fails(AuthFailureCode code) =>
    throwsA(isA<AuthFailure>().having((AuthFailure f) => f.code, 'code', code));

/// A Firebase Auth whose sign-in and sign-up fail with [code].
class _Failing extends Fake implements FirebaseAuth {
  _Failing(this.code);

  final String code;

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => Future<UserCredential>.error(FirebaseAuthException(code: code));

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => Future<UserCredential>.error(FirebaseAuthException(code: code));
}

void main() {
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore db;
  late FirebaseAuthRepository repository;

  setUp(() {
    auth = MockFirebaseAuth();
    db = FakeFirebaseFirestore();
    repository = FirebaseAuthRepository(auth, db);
  });

  Future<UserModel> register({String? phone = '  '}) => repository.register(
    fullName: '  Sara   Ahmed ',
    email: ' Sara@Example.com ',
    password: 'Secret123',
    languageCode: 'ar',
    phone: phone,
  );

  test('register signs in and saves the profile — never a password', () async {
    final UserModel user = await register();
    final String uid = auth.currentUser!.uid;

    expect(user.fullName, 'Sara Ahmed');
    expect(user.email, 'sara@example.com');
    expect(user.phone, isNull);
    final Map<String, dynamic> stored = (await db.doc('users/$uid').get())
        .data()!;
    expect(
      stored.keys,
      unorderedEquals(<String>['fullName', 'phone', 'locale', 'updatedAt']),
    );
    expect(stored['fullName'], 'Sara Ahmed');
    expect(stored['locale'], 'ar');
    expect(stored.toString(), isNot(contains('Secret123')));
  });

  test('the session names the Firebase uid and the profile name', () async {
    await register();
    final SessionUser? session = await repository.signedInUser();
    expect(session?.id, auth.currentUser!.uid);
    expect(session?.fullName, 'Sara Ahmed');
    expect(await repository.currentUser(), isNotNull);
  });

  test('a profile edit is saved and announced', () async {
    await register();
    int changes = 0;
    final StreamSubscription<void> listening = repository.changes.listen(
      (_) => changes++,
    );

    final UserModel edited = await repository.updateProfile(
      fullName: 'Sara  Al-Harbi',
      phone: '+966 50 000 0000',
    );
    await Future<void>.delayed(Duration.zero);

    expect(edited.fullName, 'Sara Al-Harbi');
    final Map<String, dynamic> stored =
        (await db.doc('users/${auth.currentUser!.uid}').get()).data()!;
    expect(stored['fullName'], 'Sara Al-Harbi');
    expect(stored['phone'], '+966 50 000 0000');
    expect(stored['locale'], 'ar', reason: 'an edit keeps the language');
    expect(changes, greaterThan(0));
    await listening.cancel();
  });

  test('the chosen language is kept with the profile', () async {
    await register();
    await repository.saveLanguage('en');
    final Map<String, dynamic> stored =
        (await db.doc('users/${auth.currentUser!.uid}').get()).data()!;
    expect(stored['locale'], 'en');
  });

  test('sign-out ends the session and leaves the profile', () async {
    await register();
    final String uid = auth.currentUser!.uid;
    await repository.logout();

    expect(await repository.currentUser(), isNull);
    expect(await repository.signedInUser(), isNull);
    expect((await db.doc('users/$uid').get()).exists, isTrue);
  });

  test(
    'a missing profile is rebuilt from the account, not left broken',
    () async {
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: 'lost',
          email: 'lost@example.com',
          displayName: 'Lost Profile',
        ),
      );
      repository = FirebaseAuthRepository(auth, db);

      final UserModel? user = await repository.currentUser();
      expect(user?.fullName, 'Lost Profile');
      expect(
        (await db.doc('users/lost').get()).data()?['fullName'],
        'Lost Profile',
      );
    },
  );

  test('a password reset is asked for with the tidied email', () async {
    await repository.sendPasswordReset(
      email: ' Sara@Example.com ',
      languageCode: 'ar',
    );
  });

  test('editing the profile signed out is refused', () async {
    expect(
      repository.updateProfile(fullName: 'Sara'),
      _fails(AuthFailureCode.storage),
    );
  });

  group('Firebase errors become the app\'s', () {
    for (final (String code, AuthFailureCode expected)
        in <(String, AuthFailureCode)>[
          ('invalid-credential', AuthFailureCode.invalidCredentials),
          ('wrong-password', AuthFailureCode.invalidCredentials),
          ('user-not-found', AuthFailureCode.invalidCredentials),
          ('network-request-failed', AuthFailureCode.network),
          ('too-many-requests', AuthFailureCode.tooManyRequests),
          ('user-disabled', AuthFailureCode.disabled),
          ('invalid-email', AuthFailureCode.invalidEmail),
          ('something-new', AuthFailureCode.unknown),
        ]) {
      test('login: $code', () {
        expect(
          FirebaseAuthRepository(
            _Failing(code),
            db,
          ).login(email: 'sara@example.com', password: 'x'),
          _fails(expected),
        );
      });
    }

    for (final (String code, AuthFailureCode expected)
        in <(String, AuthFailureCode)>[
          ('email-already-in-use', AuthFailureCode.emailTaken),
          ('weak-password', AuthFailureCode.weakPassword),
        ]) {
      test('register: $code', () {
        expect(
          FirebaseAuthRepository(_Failing(code), db).register(
            fullName: 'Sara Ahmed',
            email: 'sara@example.com',
            password: 'Secret123',
            languageCode: 'en',
          ),
          _fails(expected),
        );
      });
    }
  });
}
