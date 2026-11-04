import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';

/// The phone's own copy of each recording: written point by point while the
/// journey runs, so nothing waits on the network and nothing is lost when
/// the app stops. `FileTrackStore` implements it. Everything is keyed by
/// account and journey — one account never reads another's.
abstract interface class TrackStore {
  Future<TrackSession?> session(String uid, String journeyId);

  /// Every recording kept for [uid].
  Future<List<TrackSession>> sessions(String uid);

  Future<void> saveSession(TrackSession session);

  /// Adds [point] after the last one.
  Future<void> append(String uid, String journeyId, TrackPoint point);

  /// The points in recorded order, from the [from]-th, at most [limit].
  Future<List<TrackPoint>> points(
    String uid,
    String journeyId, {
    int from = 0,
    int? limit,
  });

  /// Forgets the recording (once the account has all of it).
  Future<void> delete(String uid, String journeyId);

  /// Forgets every recording of [uid]: the account is being deleted.
  Future<void> eraseAccount(String uid);
}
