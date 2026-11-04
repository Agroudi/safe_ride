import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/country/country_repository.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session implements SessionReader {
  String? uid;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

void main() {
  late FakeFirebaseFirestore db;
  late _Session session;

  setUp(() {
    db = FakeFirebaseFirestore();
    session = _Session()..uid = 'sara';
  });

  /// A phone: its own preferences, the shared account database.
  Future<(ProfileCountryRepository, AppPreferences)> phone([
    Map<String, Object> stored = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    final AppPreferences prefs = AppPreferences(
      await SharedPreferences.getInstance(),
    );
    return (ProfileCountryRepository(prefs, db, session), prefs);
  }

  Future<Object?> remote(String uid) async =>
      (await db.doc('users/$uid').get()).data()?['country'];

  test('nothing chosen yet is no country', () async {
    final (ProfileCountryRepository repo, _) = await phone();
    expect(repo.current(), isNull);
  });

  test('a choice is kept on the phone at once, then in the profile', () async {
    final (ProfileCountryRepository repo, AppPreferences prefs) = await phone();
    await db.doc('users/sara').set(<String, Object>{'fullName': 'Sara'});
    final Future<void> changed = repo.changes.first;

    await repo.choose('QA');
    await changed;
    expect(repo.current()?.code, 'QA');
    await pumpEventQueue();
    expect(await remote('sara'), 'QA');
    expect(prefs.country.pending, isFalse);
    expect(prefs.country.uid, 'sara');
    expect((await db.doc('users/sara').get()).data()!['fullName'], 'Sara');
  });

  test('an unsupported code is refused', () async {
    final (ProfileCountryRepository repo, _) = await phone();
    expect(() => repo.choose('US'), throwsArgumentError);
  });

  test('a new phone takes the account\'s country after sign-in', () async {
    await db.doc('users/sara').set(<String, Object>{'country': 'KW'});
    final (ProfileCountryRepository repo, AppPreferences prefs) = await phone();
    await repo.reconcile();
    expect(repo.current()?.code, 'KW');
    expect(prefs.country.pending, isFalse);
  });

  test('chosen offline (signed out): kept here, sent after sign-in', () async {
    session.uid = null;
    final (ProfileCountryRepository repo, AppPreferences prefs) = await phone();
    await repo.choose('OM');
    expect(repo.current()?.code, 'OM');
    expect(prefs.country.pending, isTrue);

    session.uid = 'sara';
    await db.doc('users/sara').set(<String, Object>{'country': 'EG'});
    await repo.reconcile();
    expect(repo.current()?.code, 'OM');
    expect(await remote('sara'), 'OM');
  });

  test('a change not yet sent wins over the account\'s older one', () async {
    await db.doc('users/sara').set(<String, Object>{'country': 'BH'});
    final (ProfileCountryRepository repo, _) = await phone(<String, Object>{
      'prefs.country': 'AE',
      'prefs.countryUid': 'sara',
      'prefs.countryPending': true,
    });
    await repo.reconcile();
    expect(repo.current()?.code, 'AE');
    expect(await remote('sara'), 'AE');
  });

  test('once sent, the account wins (changed on another phone)', () async {
    await db.doc('users/sara').set(<String, Object>{'country': 'BH'});
    final (ProfileCountryRepository repo, _) = await phone(<String, Object>{
      'prefs.country': 'AE',
      'prefs.countryUid': 'sara',
      'prefs.countryPending': false,
    });
    final Completer<void> changed = Completer<void>();
    repo.changes.listen((_) => changed.complete());
    await repo.reconcile();
    await pumpEventQueue();
    expect(repo.current()?.code, 'BH');
    expect(changed.isCompleted, isTrue);
  });

  test('an account without a country is given this phone\'s', () async {
    final (ProfileCountryRepository repo, _) = await phone(<String, Object>{
      'prefs.country': 'SA',
      'prefs.countryUid': 'omar',
      'prefs.countryPending': false,
    });
    await db.doc('users/sara').set(<String, Object>{'fullName': 'Sara'});
    await repo.reconcile();
    await pumpEventQueue();
    expect(await remote('sara'), 'SA');
  });

  test('a bad stored value reads as nothing chosen', () async {
    final (ProfileCountryRepository repo, _) = await phone(<String, Object>{
      'prefs.country': 'XX',
    });
    expect(repo.current(), isNull);
  });
}
