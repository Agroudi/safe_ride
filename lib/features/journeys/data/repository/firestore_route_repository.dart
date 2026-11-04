import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/route_repository.dart';

/// [RouteRepository] over Firestore, under the journey:
///
/// - `route/{chunk}` — up to 100 points in recorded order (`chunk` is
///   zero-padded so the documents sort by it): one write per 100 points,
///   not one per fix.
/// - `tracking/summary` — distance, point count, first and last times, and
///   whether the recording is still going.
///
/// Both are written in one batch. The rules let only the owner read or
/// write them, and only under a journey that has started.
class FirestoreRouteRepository implements RouteRepository {
  const FirestoreRouteRepository(this._db, this._session);

  final FirebaseFirestore _db;
  final SessionReader _session;

  @override
  Future<void> upload({
    required String uid,
    required String journeyId,
    required int chunk,
    required List<TrackPoint> points,
    required RouteSummary summary,
  }) {
    final WriteBatch batch = _db.batch();
    if (points.isNotEmpty) {
      batch.set(
        _db.doc('${FirestorePaths.journeyRoute(uid, journeyId)}/${_id(chunk)}'),
        <String, Object?>{
          'chunk': chunk,
          'points': <Map<String, Object?>>[for (final p in points) _point(p)],
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    batch.set(
      _db.doc(FirestorePaths.journeyTracking(uid, journeyId)),
      <String, Object?>{
        'distanceMeters': summary.distanceMeters,
        'pointCount': summary.pointCount,
        'recording': summary.recording,
        'firstAt': _time(summary.firstAt),
        'lastAt': _time(summary.lastAt),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    return batch.commit();
  }

  @override
  Future<RouteSummary?> summary(String journeyId) async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) return null;
    final Map<String, dynamic>? data =
        (await _db
                .doc(FirestorePaths.journeyTracking(user.id, journeyId))
                .get())
            .data();
    if (data == null) return null;
    return RouteSummary(
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
      pointCount: (data['pointCount'] as num?)?.toInt() ?? 0,
      recording: data['recording'] == true,
      firstAt: (data['firstAt'] as Timestamp?)?.toDate().toUtc(),
      lastAt: (data['lastAt'] as Timestamp?)?.toDate().toUtc(),
    );
  }

  static String _id(int chunk) => chunk.toString().padLeft(5, '0');

  static Timestamp? _time(DateTime? t) =>
      t == null ? null : Timestamp.fromDate(t);

  static Map<String, Object?> _point(TrackPoint p) => <String, Object?>{
    'lat': p.lat,
    'lng': p.lng,
    'at': Timestamp.fromDate(p.at),
    'acc': p.accuracy,
    'spd': p.speed,
    'seg': p.segment,
  };
}
