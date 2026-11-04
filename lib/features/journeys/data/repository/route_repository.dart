import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';

/// A journey's route in the account. `FirestoreRouteRepository` implements
/// it; the tracker sends what the phone recorded, never each fix as it
/// comes.
abstract interface class RouteRepository {
  /// How many points one chunk holds.
  static const int chunkSize = 100;

  /// Writes chunk [chunk] — the points from `chunk * chunkSize`, at most
  /// [chunkSize] of them — and [summary], together. Writing the same chunk
  /// again replaces it, so a retry never duplicates points. The returned
  /// future completes when the server has it (offline: when the connection
  /// returns).
  Future<void> upload({
    required String uid,
    required String journeyId,
    required int chunk,
    required List<TrackPoint> points,
    required RouteSummary summary,
  });

  /// What the account has for the signed-in user's journey, if anything.
  Future<RouteSummary?> summary(String journeyId);
}
