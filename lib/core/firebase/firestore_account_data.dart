import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';

/// Everything the phone may delete from `users/{uid}`, except the profile
/// itself (the authentication repository's, last): every share with its
/// public document and route, journeys with their checklists, routes and
/// summaries, contacts and devices. Connections go first, in
/// `FirestoreConnectionRepository.erase`: ending one writes to the other
/// person's record, and the invites are top level.
///
/// Firestore has no client-side recursive delete, so each path is listed
/// here: **a new collection under `users/{uid}` needs a line**. Reads go to
/// the server, never the cache, or an old journey the phone never saw would
/// stay behind; so this needs a connection, and fails rather than half
/// succeeding quietly. The collections only the backend writes are its to
/// clean (`functions/src/erase.ts`); on the Spark plan nothing ever writes
/// them.
class FirestoreAccountData implements AccountData {
  const FirestoreAccountData(this._db);

  final FirebaseFirestore _db;

  /// Firestore allows 500 writes per batch.
  static const int _batchSize = 400;

  /// A delete that hears nothing for this long counts as a lost connection.
  static const Duration _wait = Duration(seconds: 30);

  Future<List<DocumentReference<Map<String, dynamic>>>> _docs(
    String path,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> all = await _db
        .collection(path)
        .get(const GetOptions(source: Source.server))
        .timeout(_wait);
    return <DocumentReference<Map<String, dynamic>>>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in all.docs)
        d.reference,
    ];
  }

  @override
  Future<void> erase(String uid) async {
    final List<DocumentReference<Map<String, dynamic>>> journeys = await _docs(
      FirestorePaths.journeys(uid),
    );
    final List<DocumentReference<Map<String, dynamic>>> shares = await _docs(
      FirestorePaths.shareRecords(uid),
    );
    final List<DocumentReference<Map<String, dynamic>>> all =
        <DocumentReference<Map<String, dynamic>>>[
          // First, and the public document before its record: a link must not
          // outlive the account, and the record is what allows deleting it.
          for (final DocumentReference<Map<String, dynamic>> s in shares) ...[
            ...await _docs(FirestorePaths.shareRoute(s.id)),
            _db.doc(FirestorePaths.share(s.id)),
            s,
          ],
          for (final DocumentReference<Map<String, dynamic>> j in journeys) ...[
            _db.doc(FirestorePaths.journeyChecklist(uid, j.id)),
            _db.doc(FirestorePaths.journeyTracking(uid, j.id)),
            ...await _docs(FirestorePaths.journeyRoute(uid, j.id)),
          ],
          ...journeys,
          ...await _docs(FirestorePaths.contacts(uid)),
          ...await _docs(FirestorePaths.devices(uid)),
        ];
    for (int from = 0; from < all.length; from += _batchSize) {
      final WriteBatch batch = _db.batch();
      final int to = (from + _batchSize).clamp(0, all.length);
      for (final DocumentReference<Map<String, dynamic>> d in all.sublist(
        from,
        to,
      )) {
        batch.delete(d);
      }
      await batch.commit().timeout(_wait);
    }
  }
}
