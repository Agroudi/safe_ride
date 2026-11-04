import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/firebase/firestore_account_data.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_account_data.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/data/repository/firebase_auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_deletion_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/account_deletion_state.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/repository/file_track_store.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the order things were erased in.
class _Data implements AccountData {
  _Data(this.name, this.log, {this.failure});

  final String name;
  final List<String> log;
  final Object? failure;

  @override
  Future<void> erase(String uid) async {
    final Object? f = failure;
    if (f != null) throw f;
    log.add('$name:$uid');
  }
}

/// A user whose password is always wrong.
// ignore: must_be_immutable, inherited from the mock.
class _RefusingUser extends MockUser {
  _RefusingUser({super.uid, super.email});

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential? credential,
  ) => throw FirebaseAuthException(code: 'wrong-password');
}

/// A repository whose deletion the test decides.
class _Auth extends Fake implements AuthRepository {
  AuthFailure? failure;
  Completer<void>? hold;
  int calls = 0;

  @override
  Future<void> deleteAccount({required String password}) async {
    calls++;
    await hold?.future;
    final AuthFailure? f = failure;
    if (f != null) throw f;
  }
}

void main() {
  final DateTime t0 = DateTime.utc(2026, 11, 4, 9);

  group('FirestoreAccountData', () {
    late FakeFirebaseFirestore db;

    Future<int> count(String path) async =>
        (await db.collection(path).get()).size;

    Future<void> seedAccount(String uid) async {
      await db.doc('users/$uid').set(<String, Object?>{'fullName': 'X'});
      for (final String j in <String>['j1', 'j2']) {
        final String journey = 'users/$uid/journeys/$j';
        await db.doc(journey).set(<String, Object?>{'status': 'completed'});
        await db.doc('$journey/checklists/preJourney').set(<String, Object?>{});
        await db.doc('$journey/tracking/summary').set(<String, Object?>{});
        await db.doc('$journey/route/00000').set(<String, Object?>{});
        await db.doc('$journey/route/00001').set(<String, Object?>{});
      }
      await db.doc('users/$uid/contacts/c1').set(<String, Object?>{});
      await db.doc('users/$uid/devices/d1').set(<String, Object?>{});
    }

    setUp(() async {
      db = FakeFirebaseFirestore();
      await seedAccount('sara');
      await seedAccount('omar');
    });

    test('takes every journey, its parts, contacts and devices', () async {
      await FirestoreAccountData(db).erase('sara');
      expect(await count('users/sara/journeys'), 0);
      expect(await count('users/sara/journeys/j1/route'), 0);
      expect(await count('users/sara/journeys/j2/route'), 0);
      expect(await count('users/sara/journeys/j1/checklists'), 0);
      expect(await count('users/sara/journeys/j1/tracking'), 0);
      expect(await count('users/sara/contacts'), 0);
      expect(await count('users/sara/devices'), 0);
    });

    test('never touches another account', () async {
      await FirestoreAccountData(db).erase('sara');
      expect(await count('users/omar/journeys'), 2);
      expect(await count('users/omar/journeys/j1/route'), 2);
      expect(await count('users/omar/contacts'), 1);
      expect(await count('users/omar/devices'), 1);
    });

    test('running it twice is harmless', () async {
      await FirestoreAccountData(db).erase('sara');
      await FirestoreAccountData(db).erase('sara');
      expect(await count('users/sara/journeys'), 0);
    });

    test('more documents than one batch allows', () async {
      for (int i = 0; i < 450; i++) {
        await db
            .doc('users/sara/journeys/j1/route/${i + 2}')
            .set(<String, Object?>{});
      }
      await FirestoreAccountData(db).erase('sara');
      expect(await count('users/sara/journeys/j1/route'), 0);
    });
  });

  group('FirebaseAuthRepository.deleteAccount', () {
    late FakeFirebaseFirestore db;
    late MockFirebaseAuth auth;
    late List<String> log;

    FirebaseAuthRepository repository(List<AccountData> data) =>
        FirebaseAuthRepository(auth, db, accountData: () => data);

    setUp(() async {
      db = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'sara', email: 'sara@example.com'),
      );
      log = <String>[];
      await db.doc('users/sara').set(<String, Object?>{'fullName': 'Sara'});
    });

    test('erases in order, then the profile, then the sign-in', () async {
      await repository(<AccountData>[
        _Data('first', log),
        _Data('second', log),
      ]).deleteAccount(password: 'Secret123');
      expect(log, <String>['first:sara', 'second:sara']);
      expect((await db.doc('users/sara').get()).exists, isFalse);
    });

    test('a wrong password touches nothing', () async {
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: _RefusingUser(uid: 'sara', email: 'sara@example.com'),
      );
      await expectLater(
        repository(<AccountData>[
          _Data('first', log),
        ]).deleteAccount(password: 'nope'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
      expect(log, isEmpty);
      expect((await db.doc('users/sara').get()).exists, isTrue);
    });

    test('offline stops before the sign-in is deleted', () async {
      await expectLater(
        repository(<AccountData>[
          _Data(
            'cloud',
            log,
            failure: FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            ),
          ),
        ]).deleteAccount(password: 'Secret123'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure f) => f.code,
            'code',
            AuthFailureCode.network,
          ),
        ),
      );
      expect((await db.doc('users/sara').get()).exists, isTrue);
      expect(auth.currentUser, isNotNull);
    });

    test('nobody signed in is refused', () async {
      await auth.signOut();
      await expectLater(
        repository(<AccountData>[]).deleteAccount(password: 'x'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('AccountDeletionCubit', () {
    test('success', () async {
      final _Auth repository = _Auth();
      final AccountDeletionCubit cubit = AccountDeletionCubit(repository);
      await cubit.delete('p');
      expect(cubit.state, const DeletionDone());
      await cubit.close();
    });

    test('a failure can be tried again', () async {
      final _Auth repository = _Auth()
        ..failure = const AuthFailure(AuthFailureCode.network);
      final AccountDeletionCubit cubit = AccountDeletionCubit(repository);
      await cubit.delete('p');
      expect(cubit.state, const DeletionFailed(AuthFailureCode.network));
      repository.failure = null;
      await cubit.delete('p');
      expect(cubit.state, const DeletionDone());
      await cubit.close();
    });

    test('a second tap while it runs does nothing', () async {
      final _Auth repository = _Auth()..hold = Completer<void>();
      final AccountDeletionCubit cubit = AccountDeletionCubit(repository);
      final Future<void> first = cubit.delete('p');
      await cubit.delete('p');
      repository.hold!.complete();
      await first;
      expect(repository.calls, 1);
      await cubit.close();
    });
  });

  group('on the phone', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('erase');
    });

    tearDown(() => root.delete(recursive: true));

    PotentialIncident incident(
      String id,
      String uid, {
      IncidentStatus status = IncidentStatus.resolved,
      DateTime? at,
    }) => PotentialIncident(
      id: id,
      journeyId: 'j1',
      uid: uid,
      type: IncidentType.prolongedStop,
      status: status,
      confidence: IncidentConfidence.medium,
      detectedAt: at ?? t0,
      updatedAt: at ?? t0,
      reason: 'test',
    );

    SafetyCheck check(
      String id,
      String uid, {
      SafetyCheckStatus status = SafetyCheckStatus.confirmedSafe,
      DateTime? at,
    }) => SafetyCheck(
      id: id,
      incidentId: 'e1',
      journeyId: 'j1',
      uid: uid,
      status: status,
      startedAt: at ?? t0,
      deadline: (at ?? t0).add(const Duration(seconds: 15)),
    );

    test('route files: only that account\'s go', () async {
      final FileTrackStore store = FileTrackStore(root: () async => root);
      for (final String uid in <String>['sara', 'omar']) {
        await store.saveSession(
          TrackSession(
            journeyId: 'j1',
            uid: uid,
            recording: true,
            startedAt: t0,
          ),
        );
        await store.append(
          uid,
          'j1',
          TrackPoint(lat: 1, lng: 2, at: t0, accuracy: 5, segment: 0),
        );
      }
      await store.eraseAccount('sara');
      expect(await store.sessions('sara'), isEmpty);
      expect(await store.points('sara', 'j1'), isEmpty);
      expect(await store.sessions('omar'), hasLength(1));
      await store.eraseAccount('sara');
    });

    test('incidents: only that account\'s go', () async {
      final FileIncidentRepository repository = FileIncidentRepository(
        root: () async => root,
        clock: () => t0,
      );
      await repository.put(incident('a', 'sara'));
      await repository.put(incident('b', 'omar'));
      await repository.eraseAccount('sara');
      expect(await repository.forUser('sara'), isEmpty);
      expect(await repository.forUser('omar'), hasLength(1));
    });

    test('checks: only that account\'s go', () async {
      final FileSafetyCheckRepository repository = FileSafetyCheckRepository(
        root: () async => root,
        clock: () => t0,
      );
      await repository.put(check('a', 'sara'));
      await repository.put(check('b', 'omar'));
      await repository.eraseAccount('sara');
      expect(await repository.forUser('sara'), isEmpty);
      expect(await repository.forUser('omar'), hasLength(1));
    });

    test('closed incidents leave after 90 days; open ones never', () async {
      final DateTime old = t0.subtract(const Duration(days: 91));
      final FileIncidentRepository repository = FileIncidentRepository(
        root: () async => root,
        clock: () => t0,
      );
      await repository.put(incident('old', 'sara', at: old));
      await repository.put(
        incident(
          'unanswered',
          'sara',
          at: old,
          status: IncidentStatus.escalationReady,
        ),
      );
      await repository.put(incident('new', 'sara'));
      expect(
        (await repository.forUser('sara')).map((PotentialIncident i) => i.id),
        <String>['unanswered', 'new'],
      );
    });

    test('finished checks leave after 90 days; unanswered never', () async {
      final DateTime old = t0.subtract(const Duration(days: 91));
      final FileSafetyCheckRepository repository = FileSafetyCheckRepository(
        root: () async => root,
        clock: () => t0,
      );
      await repository.put(check('old', 'sara', at: old));
      await repository.put(
        check(
          'unanswered',
          'sara',
          at: old,
          status: SafetyCheckStatus.escalationReady,
        ),
      );
      await repository.put(check('new', 'sara'));
      expect(
        (await repository.forUser('sara')).map((SafetyCheck c) => c.id),
        <String>['unanswered', 'new'],
      );
    });

    test('the chosen country goes only if it was this account\'s', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppPreferences prefs = AppPreferences(
        await SharedPreferences.getInstance(),
      );
      await prefs.setCountry('SA', uid: 'sara', pending: false);
      await PreferencesAccountData(prefs).erase('omar');
      expect(prefs.country.code, 'SA');
      await PreferencesAccountData(prefs).erase('sara');
      expect(prefs.country.code, isNull);
      expect(prefs.country.uid, isNull);
    });
  });
}
