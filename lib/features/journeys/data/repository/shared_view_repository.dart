import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';

/// What a link gave at one moment. [view] null with [ended] means the share is
/// over, or never existed: the two look the same on purpose.
final class SharedViewEvent {
  const SharedViewEvent({this.view, this.ended = false, this.offline = false});

  final SharedView? view;
  final bool ended;

  /// Not confirmed by the server: a copy on this device, or nothing yet.
  final bool offline;
}

/// The recipient's side: read-only, with no account.
abstract interface class SharedViewRepository {
  Stream<SharedViewEvent> watch(String token);

  /// One chunk of the route; empty when it cannot be read.
  Future<List<SharedRoutePoint>> chunk(String token, int chunk);
}

class FirestoreSharedViewRepository implements SharedViewRepository {
  const FirestoreSharedViewRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<SharedViewEvent> watch(String token) {
    final StreamController<SharedViewEvent> out =
        StreamController<SharedViewEvent>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? listening;
    out
      ..onListen = () {
        listening = _db
            .doc(FirestorePaths.share(token))
            .snapshots(includeMetadataChanges: true)
            .listen(
              (DocumentSnapshot<Map<String, dynamic>> s) => out.add(_event(s)),
              onError: (Object e) {
                // Refused means over; anything else is the connection.
                final bool refused =
                    e is FirebaseException && e.code == 'permission-denied';
                out.add(SharedViewEvent(ended: refused, offline: !refused));
              },
            );
      }
      ..onCancel = () => listening?.cancel();
    return out.stream;
  }

  static SharedViewEvent _event(DocumentSnapshot<Map<String, dynamic>> s) {
    final bool cached = s.metadata.isFromCache;
    final Map<String, dynamic>? data = s.data();
    if (data == null) {
      return SharedViewEvent(ended: !cached, offline: cached);
    }
    final SharedView? view = SharedView.read(data);
    return SharedViewEvent(view: view, ended: view == null, offline: cached);
  }

  @override
  Future<List<SharedRoutePoint>> chunk(String token, int chunk) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> s = await _db
          .doc(
            '${FirestorePaths.shareRoute(token)}/'
            '${chunk.toString().padLeft(5, '0')}',
          )
          .get();
      final Object? points = s.data()?['points'];
      if (points is! List) return const <SharedRoutePoint>[];
      return <SharedRoutePoint>[
        for (final Object? p in points) ?SharedRoutePoint.read(p),
      ];
    } on FirebaseException {
      return const <SharedRoutePoint>[];
    }
  }
}
