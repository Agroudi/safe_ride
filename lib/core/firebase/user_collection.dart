import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One live query on a collection under `users/{uid}`, shared by every screen
/// that reads it.
///
/// The first read for an account starts a listener; later reads return what
/// it last delivered, so a cubit reloading after a change costs no Firestore
/// reads — only the documents that changed are billed
/// (docs/firebase-architecture.md §9.3). Offline it serves the phone's
/// cache. A different account starts it again on the next read; so does an
/// error, but only after [retryAfter]: every failure fires [changes], every
/// list reloads on it, and restarting at once would loop for as long as a
/// refusal lasts, at the phone's battery and the project's quota. A document
/// that cannot be read is skipped, so one bad record never takes the whole
/// list — and everything waiting on it — down.
class UserCollection<T> {
  UserCollection({
    required FirebaseFirestore db,
    required String Function(String uid) path,
    required T Function(String id, Map<String, dynamic> data) read,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? query,
    DateTime Function()? clock,
  }) : _db = db,
       _path = path,
       _read = read,
       _query = query,
       _clock = clock ?? DateTime.now;

  /// How long a failed listener stays failed.
  static const Duration retryAfter = Duration(seconds: 30);

  final FirebaseFirestore _db;
  final String Function(String uid) _path;
  final T Function(String id, Map<String, dynamic> data) _read;
  final Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)?
  _query;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  _Watch<T>? _watch;
  ({String uid, Object error, DateTime at})? _failed;

  /// Fires on every snapshot the listener delivers.
  Stream<void> get changes => _changes.stream;

  CollectionReference<Map<String, dynamic>> ref(String uid) =>
      _db.collection(_path(uid));

  /// [uid]'s documents, as the listener last saw them. Throws what the
  /// listener failed with (a `FirebaseException`).
  Future<List<T>> items(String uid) async {
    final ({String uid, Object error, DateTime at})? failed = _failed;
    if (_watch == null &&
        failed != null &&
        failed.uid == uid &&
        _clock().difference(failed.at) < retryAfter) {
      throw failed.error;
    }
    final _Watch<T> watch = _watch?.uid == uid ? _watch! : _start(uid);
    await watch.ready.future;
    final Object? error = watch.error;
    if (error != null) throw error;
    return watch.items;
  }

  T? _readable(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    try {
      return _read(d.id, d.data());
    } on Object catch (e) {
      debugPrint(
        'Skipped a document that could not be read (${e.runtimeType})',
      );
      return null;
    }
  }

  _Watch<T> _start(String uid) {
    unawaited(_watch?.subscription?.cancel());
    final _Watch<T> watch = _Watch<T>(uid);
    _watch = watch;
    final Query<Map<String, dynamic>> query =
        _query?.call(ref(uid)) ?? ref(uid);
    watch.subscription = query.snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        watch.items = <T>[
          for (final QueryDocumentSnapshot<Map<String, dynamic>> d
              in snapshot.docs)
            ?_readable(d),
        ];
        watch.error = null;
        if (!watch.ready.isCompleted) watch.ready.complete();
        _changes.add(null);
      },
      onError: (Object error) {
        watch.error = error;
        if (!watch.ready.isCompleted) watch.ready.complete();
        // A failed listener is finished; a later read starts a new one.
        if (identical(_watch, watch)) {
          _watch = null;
          _failed = (uid: uid, error: error, at: _clock());
        }
        _changes.add(null);
      },
    );
    return watch;
  }
}

class _Watch<T> {
  _Watch(this.uid);

  final String uid;
  final Completer<void> ready = Completer<void>();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
  List<T> items = <T>[];
  Object? error;
}
