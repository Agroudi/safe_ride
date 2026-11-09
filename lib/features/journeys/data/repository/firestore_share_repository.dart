import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/repository/share_repository.dart';

/// [ShareRepository] over Firestore: a public document at `shares/{token}`
/// with no owner in it, and the proof of ownership at
/// `users/{uid}/shares/{token}` (`firestore.rules`).
class FirestoreShareRepository implements ShareRepository {
  const FirestoreShareRepository(this._db);

  final FirebaseFirestore _db;

  /// How long a transaction may take before it counts as unreachable.
  static const Duration _wait = Duration(seconds: 10);

  DocumentReference<Map<String, dynamic>> _share(String token) =>
      _db.doc(FirestorePaths.share(token));

  DocumentReference<Map<String, dynamic>> _record(String uid, String token) =>
      _db.doc('${FirestorePaths.shareRecords(uid)}/$token');

  CollectionReference<Map<String, dynamic>> _route(String token) =>
      _db.collection(FirestorePaths.shareRoute(token));

  static String _chunkId(int chunk) => chunk.toString().padLeft(5, '0');

  @override
  Future<ShareRecord> create({
    required String uid,
    required String token,
    required ShareKind kind,
    required DateTime expiresAt,
    String? journeyId,
    SharedPlace? origin,
    SharedPlace? destination,
  }) async {
    final Timestamp expires = Timestamp.fromDate(expiresAt.toUtc());
    final bool journey = kind == ShareKind.journey;
    await _guard(
      () => _db.runTransaction<void>(
        (Transaction tx) async {
          tx
            ..set(_share(token), <String, Object?>{
              'kind': kind.name,
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': expires,
              'updatedAt': FieldValue.serverTimestamp(),
              'tracking': 'waiting',
              if (journey) ...<String, Object?>{
                'journeyStatus': 'active',
                'origin': ?origin?.toFirestore(),
                'destination': ?destination?.toFirestore(),
              },
              'routeChunks': 0,
              'routeVersion': 0,
            })
            ..set(_record(uid, token), <String, Object?>{
              'kind': kind.name,
              'journeyId': ?journeyId,
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': expires,
            });
        },
        timeout: _wait,
        maxAttempts: 1,
      ),
    );
    return ShareRecord(
      token: token,
      kind: kind,
      expiresAt: expiresAt.toUtc(),
      journeyId: journeyId,
    );
  }

  /// A transaction, not a write, and that is the point. A plain write made
  /// offline waits in the phone's queue and is stamped with the server's time
  /// **when it finally lands**, so a position an hour old would arrive looking
  /// live, behind a backlog of others. A transaction fails instead: nothing is
  /// left queued, and the next try sends only the latest position. Its read
  /// also tells the phone when the share was stopped from elsewhere.
  @override
  Future<void> publish(String token, ShareUpdate update) => _guard(
    () => _db.runTransaction<void>(
      (Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> now = await tx.get(
          _share(token),
        );
        if (!now.exists) throw const ShareGone();
        tx.update(_share(token), _fields(update));
        _writeChunks(tx, token, update);
      },
      timeout: _wait,
      maxAttempts: 1,
    ),
  );

  @override
  Future<void> finish(
    String uid,
    String token, {
    required DateTime expiresAt,
    required ShareUpdate last,
  }) {
    final Timestamp expires = Timestamp.fromDate(expiresAt.toUtc());
    return _guard(
      () => _db.runTransaction<void>(
        (Transaction tx) async {
          final DocumentSnapshot<Map<String, dynamic>> now = await tx.get(
            _share(token),
          );
          if (!now.exists) throw const ShareGone();
          tx
            ..update(_share(token), <String, Object?>{
              ..._fields(last),
              'tracking': 'ended',
              'journeyStatus': 'finished',
              'expiresAt': expires,
              // Where the journey ended stays out of it.
              'location': FieldValue.delete(),
              'locationAt': FieldValue.delete(),
            })
            ..update(_record(uid, token), <String, Object?>{
              'expiresAt': expires,
            });
          _writeChunks(tx, token, last);
        },
        timeout: _wait,
        maxAttempts: 1,
      ),
    );
  }

  Map<String, Object?> _fields(ShareUpdate update) {
    final SharePosition? p = update.position;
    return <String, Object?>{
      'tracking': update.tracking,
      'updatedAt': FieldValue.serverTimestamp(),
      if (p != null)
        'location': <String, Object>{
          'lat': p.lat,
          'lng': p.lng,
          'accuracy': p.accuracy,
          'fixAt': Timestamp.fromDate(p.fixAt.toUtc()),
        },
      if (p != null || update.confirmed)
        'locationAt': FieldValue.serverTimestamp(),
      'distanceMeters': ?update.distanceMeters,
      'routeChunks': ?update.routeChunks,
      'routeVersion': ?update.routeVersion,
    };
  }

  void _writeChunks(Transaction tx, String token, ShareUpdate update) {
    update.chunks.forEach((int chunk, List<SharedRoutePoint> points) {
      tx.set(_route(token).doc(_chunkId(chunk)), <String, Object>{
        'chunk': chunk,
        'points': <Map<String, Object>>[
          for (final SharedRoutePoint p in points) p.toFirestore(),
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<bool> stop(String uid, String token) async {
    final QuerySnapshot<Map<String, dynamic>>? route = await _routeOrNone(
      token,
    );
    final WriteBatch batch = _db.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d
        in route?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      batch.delete(d.reference);
    }
    batch
      ..delete(_share(token))
      ..delete(_record(uid, token));
    return settle(batch.commit());
  }

  /// Offline the list may fail; the share is stopped regardless, and a chunk
  /// left behind can no longer be read.
  Future<QuerySnapshot<Map<String, dynamic>>?> _routeOrNone(
    String token,
  ) async {
    try {
      return await _route(token).get().timeout(const Duration(seconds: 3));
    } on Object {
      return null;
    }
  }

  @override
  Future<List<ShareRecord>> records(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> all = await _db
        .collection(FirestorePaths.shareRecords(uid))
        .get();
    return <ShareRecord>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in all.docs)
        ?ShareRecord.read(d.id, d.data()),
    ];
  }

  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } on ShareGone {
      rethrow;
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        // The rules say no: stopped, expired, or not deployed.
        'permission-denied' || 'not-found' => const ShareGone(),
        _ => const ShareFailure(ShareFailureCode.offline),
      };
    } on TimeoutException {
      throw const ShareFailure(ShareFailureCode.offline);
    }
  }
}
