import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_connection_repository.dart';

import '../connection_fakes.dart';

Matcher fails(ConnectionFailureCode code) => throwsA(
  isA<ConnectionFailure>().having(
    (ConnectionFailure f) => f.code,
    'code',
    code,
  ),
);

void main() {
  late FailingFirestore db;
  late FakeConnectionLinks links;
  late DateTime now;
  late FirestoreConnectionRepository sara;
  late FirestoreConnectionRepository omar;
  final String token = BearerToken.generate(Random(1));

  Future<Map<String, dynamic>?> read(String path) async =>
      (await db.doc(path).get()).data();

  /// Sara again, with tokens of its own.
  FirestoreConnectionRepository saraAgain() =>
      connectionsFor(db, 'sara', clock: () => now);

  setUp(() async {
    db = FailingFirestore();
    links = FakeConnectionLinks();
    now = DateTime.utc(2026, 11, 5, 12);
    sara = connectionsFor(
      db,
      'sara',
      links: links,
      clock: () => now,
      newToken: () => token,
    );
    omar = connectionsFor(db, 'omar', links: links, clock: () => now);
    await db.doc('users/sara').set(<String, Object>{'fullName': 'Sara Ahmed'});
    await db.doc('users/omar').set(<String, Object>{'fullName': 'Omar Ali'});
    await db.doc('users/mona').set(<String, Object>{'fullName': 'Mona Saleh'});
  });

  group('inviting', () {
    test('writes what the rules ask for, for three days', () async {
      final ConnectionInviteModel invite = await sara.createInvite();

      expect(invite.token, token);
      expect(invite.inviterName, 'Sara Ahmed');
      final Map<String, dynamic> stored = (await read(
        'connectionInvites/$token',
      ))!;
      expect(stored.keys.toSet(), <String>{
        'inviterUid',
        'inviterName',
        'status',
        'createdAt',
        'expiresAt',
      });
      expect(stored['inviterUid'], 'sara');
      expect(stored['status'], 'pending');
      expect(
        (stored['expiresAt'] as Timestamp).toDate().toUtc(),
        now.add(const Duration(hours: 72)),
      );
    });

    test('tokens are the secure kind by default', () async {
      final FirestoreConnectionRepository real = connectionsFor(db, 'sara');
      final ConnectionInviteModel a = await real.createInvite();
      final ConnectionInviteModel b = await real.createInvite();
      expect(BearerToken.isValid(a.token), isTrue);
      expect(a.token, isNot(b.token));
    });

    test('takes its name from the profile, not from the session', () async {
      await db.doc('users/sara').update(<String, Object>{'fullName': 'Sara A'});
      expect((await sara.createInvite()).inviterName, 'Sara A');
    });

    test('with no profile name makes nothing', () async {
      await db.doc('users/sara').delete();
      await expectLater(
        sara.createInvite(),
        fails(ConnectionFailureCode.profileMissing),
      );
      expect(await read('connectionInvites/$token'), isNull);
    });

    test(
      'a page that is not there means no invite, never a dead link',
      () async {
        links.ready = false;
        await expectLater(
          sara.createInvite(),
          fails(ConnectionFailureCode.unavailable),
        );
        expect(await read('connectionInvites/$token'), isNull);
      },
    );

    test('offline makes nothing, and leaves nothing queued', () async {
      links.offline = true;
      await expectLater(
        sara.createInvite(),
        fails(ConnectionFailureCode.offline),
      );
      links.offline = false;
      db.transactionError = 'unavailable';
      await expectLater(
        sara.createInvite(),
        fails(ConnectionFailureCode.offline),
      );
      expect(await read('connectionInvites/$token'), isNull);
    });

    test('rules that refuse read as not available', () async {
      db.transactionError = 'permission-denied';
      await expectLater(
        sara.createInvite(),
        fails(ConnectionFailureCode.unavailable),
      );
    });

    test('at most five wait at once; an expired one does not count', () async {
      final FirestoreConnectionRepository many = saraAgain();
      for (int i = 0; i < 5; i++) {
        await many.createInvite();
      }
      await expectLater(
        many.createInvite(),
        fails(ConnectionFailureCode.tooMany),
      );
      now = now.add(const Duration(hours: 73));
      await many.createInvite();
    });

    test('a used invite is cleared by the next one', () async {
      await sara.createInvite();
      await omar.accept(token);
      await saraAgain().createInvite();
      expect(await read('connectionInvites/$token'), isNull);
    });

    test('lists only the account\'s own, unused, newest first', () async {
      await sara.createInvite();
      now = now.add(const Duration(minutes: 1));
      final ConnectionInviteModel second = await saraAgain().createInvite();

      final List<ConnectionInviteModel> mine = await sara.invites();
      expect(mine.map((ConnectionInviteModel i) => i.token), <String>[
        second.token,
        token,
      ]);
      expect(await omar.invites(), isEmpty);

      await omar.accept(second.token);
      await pumpEventQueue();
      expect((await sara.invites()).single.token, token);
    });

    test('what landed with its answer lost counts as done', () async {
      db.answerLost = true;
      final ConnectionInviteModel made = await sara.createInvite();
      expect(made.token, token);
      await sara.cancelInvite(token);
      expect(await read('connectionInvites/$token'), isNull);
    });

    test('cancelling ends it; offline it does not pretend', () async {
      await sara.createInvite();
      db.transactionError = 'unavailable';
      await expectLater(
        sara.cancelInvite(token),
        fails(ConnectionFailureCode.offline),
      );
      expect(await read('connectionInvites/$token'), isNotNull);

      db.transactionError = null;
      await sara.cancelInvite(token);
      expect(await read('connectionInvites/$token'), isNull);
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
    });
  });

  group('previewing', () {
    test('says who is inviting', () async {
      await sara.createInvite();
      expect((await omar.preview(token)).inviterName, 'Sara Ahmed');
    });

    test('a malformed token never reaches the server', () async {
      await expectLater(
        omar.preview('nope'),
        fails(ConnectionFailureCode.invalid),
      );
    });

    test('an unknown token is simply no longer valid', () async {
      await expectLater(
        omar.preview(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
    });

    test('the inviter is told it is their own', () async {
      await sara.createInvite();
      await expectLater(
        sara.preview(token),
        fails(ConnectionFailureCode.ownInvite),
      );
    });

    test('an expired one is no longer valid', () async {
      await sara.createInvite();
      now = now.add(const Duration(hours: 72));
      await expectLater(
        omar.preview(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
    });

    test('a used one: known to its acceptor, closed to anyone else', () async {
      await sara.createInvite();
      await omar.accept(token);
      await expectLater(
        omar.preview(token),
        fails(ConnectionFailureCode.alreadyConnected),
      );
      await expectLater(
        connectionsFor(db, 'mona', clock: () => now).preview(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
    });

    test('a second invite between two connected people says so', () async {
      await sara.createInvite();
      await omar.accept(token);
      final ConnectionInviteModel again = await saraAgain().createInvite();
      await expectLater(
        omar.preview(again.token),
        fails(ConnectionFailureCode.alreadyConnected),
      );
    });

    test('signed out, nothing is read', () async {
      await sara.createInvite();
      await expectLater(
        connectionsFor(db, null).preview(token),
        fails(ConnectionFailureCode.signedOut),
      );
    });
  });

  group('accepting', () {
    setUp(() => sara.createInvite());

    test('makes both sides, each with the other\'s real name', () async {
      final ConnectionModel made = await omar.accept(token);

      expect(made.contactUid, 'sara');
      expect(made.status, ConnectionStatus.accepted);

      final Map<String, dynamic> mine = (await read(
        'users/omar/connections/sara',
      ))!;
      final Map<String, dynamic> theirs = (await read(
        'users/sara/connections/omar',
      ))!;
      expect(mine['contactName'], 'Sara Ahmed');
      expect(theirs['contactName'], 'Omar Ali');
      for (final Map<String, dynamic> side in <Map<String, dynamic>>[
        mine,
        theirs,
      ]) {
        expect(side['status'], 'accepted');
        expect(side['inviteId'], token);
        expect(side['permissions'], <String, bool>{'safetyAlerts': false});
        expect(side.containsKey('nickname'), isFalse);
      }
      final Map<String, dynamic> invite = (await read(
        'connectionInvites/$token',
      ))!;
      expect(invite['status'], 'accepted');
      expect(invite['acceptedBy'], 'omar');
    });

    test('shows on both accounts\' lists', () async {
      await omar.accept(token);
      await pumpEventQueue();
      expect((await omar.connections()).single.displayName, 'Sara Ahmed');
      expect((await sara.connections()).single.displayName, 'Omar Ali');
    });

    test('twice is refused, and changes nothing', () async {
      await omar.accept(token);
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.alreadyConnected),
      );
      expect(await sara.connections(), hasLength(1));
    });

    test('a used invite is closed to a second person', () async {
      await omar.accept(token);
      await expectLater(
        connectionsFor(db, 'mona', clock: () => now).accept(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
      expect(await read('users/mona/connections/sara'), isNull);
      expect(await read('users/sara/connections/mona'), isNull);
    });

    test('one\'s own is refused', () async {
      await expectLater(
        sara.accept(token),
        fails(ConnectionFailureCode.ownInvite),
      );
      expect(await read('users/sara/connections/sara'), isNull);
    });

    test('an expired one is refused', () async {
      now = now.add(const Duration(hours: 72));
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
      expect(await read('users/omar/connections/sara'), isNull);
    });

    test('a malformed token and being signed out make nothing', () async {
      await expectLater(
        omar.accept('nope'),
        fails(ConnectionFailureCode.invalid),
      );
      await expectLater(
        connectionsFor(db, null).accept(token),
        fails(ConnectionFailureCode.signedOut),
      );
    });

    test('with no profile name makes nothing', () async {
      await db.doc('users/omar').delete();
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.profileMissing),
      );
      expect((await read('connectionInvites/$token'))!['status'], 'pending');
    });

    test('offline fails and queues nothing: it can be tried again', () async {
      db.transactionError = 'unavailable';
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.offline),
      );
      expect(await read('users/omar/connections/sara'), isNull);
      expect((await read('connectionInvites/$token'))!['status'], 'pending');

      db.transactionError = null;
      await omar.accept(token);
      expect(await read('users/omar/connections/sara'), isNotNull);
    });

    test(
      'the rules saying no reads as an invite that cannot be used',
      () async {
        db.transactionError = 'permission-denied';
        await expectLater(
          omar.accept(token),
          fails(ConnectionFailureCode.noLongerValid),
        );
      },
    );

    test('a commit that landed with its answer lost is a success', () async {
      db.answerLost = true;
      final ConnectionModel made = await omar.accept(token);
      expect(made.contactUid, 'sara');
      expect(
        (await read('users/omar/connections/sara'))!['status'],
        'accepted',
      );
    });

    test('any other failure is a lost connection, never a refusal', () async {
      for (final String code in <String>[
        'unavailable',
        'deadline-exceeded',
        'failed-precondition',
        'unknown',
      ]) {
        db.transactionError = code;
        await expectLater(
          omar.accept(token),
          fails(ConnectionFailureCode.offline),
        );
      }
    });

    test('losing a race, past the retries, is a lost connection', () async {
      db.transactionError = 'aborted';
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.offline),
      );
    });

    test('a damaged invite is refused, not guessed at', () async {
      await db.doc('connectionInvites/$token').update(<String, Object>{
        'status': 'nonsense',
      });
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.noLongerValid),
      );
    });

    test('the twenty-first person is refused', () async {
      for (int i = 0; i < FirestoreConnectionRepository.maxConnections; i++) {
        await db.doc('users/omar/connections/p$i').set(<String, Object>{
          'ownerUid': 'omar',
          'contactUid': 'p$i',
          'contactName': 'Person $i',
          'status': 'accepted',
          'inviteId': token,
          'createdAt': Timestamp.fromDate(now),
          'acceptedAt': Timestamp.fromDate(now),
          'permissions': <String, bool>{'safetyAlerts': false},
        });
      }
      await expectLater(
        omar.accept(token),
        fails(ConnectionFailureCode.tooMany),
      );
    });
  });

  group('ending', () {
    setUp(() async {
      await sara.createInvite();
      await omar.accept(token);
    });

    test('ends both sides, saying who and when', () async {
      await sara.revoke('omar');
      for (final String path in <String>[
        'users/sara/connections/omar',
        'users/omar/connections/sara',
      ]) {
        final Map<String, dynamic> side = (await read(path))!;
        expect(side['status'], 'revoked');
        expect(side['revokedBy'], 'sara');
        expect(side['revokedAt'], isNotNull);
      }
      expect(
        (await omar.connections()).single.status,
        ConnectionStatus.revoked,
      );
    });

    test('either person can', () async {
      await omar.revoke('sara');
      expect((await read('users/sara/connections/omar'))!['revokedBy'], 'omar');
    });

    test('an ended one stays ended, with who ended it', () async {
      await sara.revoke('omar');
      await omar.revoke('sara');
      expect((await read('users/omar/connections/sara'))!['revokedBy'], 'sara');
    });

    test('an end that landed with its answer lost is a success', () async {
      db.answerLost = true;
      await sara.revoke('omar');
      expect((await read('users/sara/connections/omar'))!['status'], 'revoked');
    });

    test('offline does not claim it happened', () async {
      db.transactionError = 'unavailable';
      await expectLater(
        sara.revoke('omar'),
        fails(ConnectionFailureCode.offline),
      );
      expect(
        (await read('users/sara/connections/omar'))!['status'],
        'accepted',
      );
      expect(
        (await read('users/omar/connections/sara'))!['status'],
        'accepted',
      );
    });

    test('their side being gone still ends this one', () async {
      db
        ..transactionError = 'not-found'
        ..failuresLeft = 1;
      await db.doc('users/omar/connections/sara').delete();
      await sara.revoke('omar');
      expect((await read('users/sara/connections/omar'))!['status'], 'revoked');
    });

    test('a new invite starts over, with no nickname left behind', () async {
      await sara.rename('omar', 'Brother');
      await sara.revoke('omar');
      final ConnectionInviteModel again = await saraAgain().createInvite();
      await omar.accept(again.token);

      final Map<String, dynamic> side = (await read(
        'users/sara/connections/omar',
      ))!;
      expect(side['status'], 'accepted');
      expect(side.containsKey('nickname'), isFalse);
      expect(side.containsKey('revokedAt'), isFalse);
      expect(side.containsKey('revokedBy'), isFalse);
    });

    test('clearing takes it off this account\'s list only', () async {
      await sara.revoke('omar');
      await sara.clear('omar');
      expect(await read('users/sara/connections/omar'), isNull);
      expect(await read('users/omar/connections/sara'), isNotNull);
    });
  });

  group('a nickname', () {
    setUp(() async {
      await sara.createInvite();
      await omar.accept(token);
    });

    test('changes this side only', () async {
      await sara.rename('omar', '  Brother ');
      expect((await sara.connections()).single.displayName, 'Brother');
      expect(
        (await read('users/sara/connections/omar'))!['nickname'],
        'Brother',
      );
      expect(
        (await read('users/omar/connections/sara'))!.containsKey('nickname'),
        isFalse,
      );
    });

    test('blank takes it away', () async {
      await sara.rename('omar', 'Brother');
      await sara.rename('omar', '  ');
      expect(
        (await read('users/sara/connections/omar'))!.containsKey('nickname'),
        isFalse,
      );
    });
  });

  group('accounts stay apart', () {
    test('a third account sees nothing of a connection', () async {
      await sara.createInvite();
      await omar.accept(token);
      final FirestoreConnectionRepository mona = connectionsFor(db, 'mona');
      expect(await mona.connections(), isEmpty);
      expect(await mona.invites(), isEmpty);
    });

    test('a signed-out reader gets no list', () async {
      await expectLater(
        connectionsFor(db, null).connections(),
        fails(ConnectionFailureCode.signedOut),
      );
    });

    test('a record that cannot be read is skipped', () async {
      await db.doc('users/sara/connections/x').set(<String, Object>{
        'status': 'nonsense',
      });
      expect(await sara.connections(), isEmpty);
    });

    test('a change on the other phone reaches this list', () async {
      await sara.createInvite();
      await sara.connections();
      final Future<void> heard = sara.changes.first;
      await omar.accept(token);
      await heard;
      expect((await sara.connections()).single.contactUid, 'omar');
    });
  });

  group('deleting an account', () {
    test('tells the other side and leaves nothing of its own', () async {
      await sara.createInvite();
      await omar.accept(token);
      final ConnectionInviteModel waiting = await saraAgain().createInvite();
      final ConnectionInviteModel others = await connectionsFor(
        db,
        'omar',
        clock: () => now,
      ).createInvite();

      await sara.erase('sara');

      expect(await read('users/sara/connections/omar'), isNull);
      expect(await read('connectionInvites/$token'), isNull);
      expect(await read('connectionInvites/${waiting.token}'), isNull);
      final Map<String, dynamic> theirs = (await read(
        'users/omar/connections/sara',
      ))!;
      expect(theirs['status'], 'revoked');
      expect(theirs['revokedBy'], 'sara');
      expect(await read('connectionInvites/${others.token}'), isNotNull);
    });

    test('runs twice harmlessly', () async {
      await sara.createInvite();
      await omar.accept(token);
      await sara.erase('sara');
      await sara.erase('sara');
    });
  });
}
