import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/firebase/user_collection.dart';

// ignore: subtype_of_sealed_class
/// A query whose every listener is refused, counting them.
class _Refused extends Fake implements Query<Map<String, dynamic>> {
  final List<int> _listeners = <int>[];

  int get listeners => _listeners.length;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    _listeners.add(1);
    return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late DateTime now;

  setUp(() {
    db = FakeFirebaseFirestore();
    now = DateTime.utc(2026, 11, 4, 9);
  });

  test('one bad document never takes the list down', () async {
    await db.doc('users/sara/things/good').set(<String, Object?>{'n': 1});
    await db.doc('users/sara/things/bad').set(<String, Object?>{'n': 'x'});
    final UserCollection<int> things = UserCollection<int>(
      db: db,
      path: (String uid) => 'users/$uid/things',
      read: (String id, Map<String, dynamic> data) => data['n'] as int,
    );
    expect(
      await things.items('sara').timeout(const Duration(seconds: 2)),
      <int>[1],
    );
  });

  test('a refusal is not retried in a loop', () async {
    final _Refused refused = _Refused();
    final UserCollection<int> things = UserCollection<int>(
      db: db,
      path: (String uid) => 'users/$uid/things',
      read: (String id, Map<String, dynamic> data) => 0,
      query: (_) => refused,
      clock: () => now,
    );
    // What every list cubit does on `changes`: read again.
    int reloads = 0;
    final StreamSubscription<void> reloading = things.changes.listen((_) async {
      if (reloads++ > 50) return;
      try {
        await things.items('sara');
      } on FirebaseException {
        // The screen shows its failure.
      }
    });

    await expectLater(things.items('sara'), throwsA(isA<FirebaseException>()));
    await pumpEventQueue();
    expect(refused.listeners, 1);

    await expectLater(things.items('sara'), throwsA(isA<FirebaseException>()));
    expect(refused.listeners, 1);

    now = now.add(UserCollection.retryAfter);
    await expectLater(things.items('sara'), throwsA(isA<FirebaseException>()));
    expect(refused.listeners, 2);
    await reloading.cancel();
  });

  test('another account is not held back by the failure', () async {
    int calls = 0;
    final _Refused refused = _Refused();
    final UserCollection<int> things = UserCollection<int>(
      db: db,
      path: (String uid) => 'users/$uid/things',
      read: (String id, Map<String, dynamic> data) => 0,
      query: (Query<Map<String, dynamic>> q) => calls++ == 0 ? refused : q,
      clock: () => now,
    );
    await expectLater(things.items('sara'), throwsA(isA<FirebaseException>()));
    expect(await things.items('omar'), isEmpty);
  });
}
