import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';

/// A position for a share. [fixAt] is when the phone took it.
final class SharePosition {
  const SharePosition({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.fixAt,
  });

  final double lat;
  final double lng;
  final double accuracy;
  final DateTime fixAt;
}

/// One update of a share. Fields left null do not change.
final class ShareUpdate {
  const ShareUpdate({
    required this.tracking,
    this.position,
    this.confirmed = false,
    this.distanceMeters,
    this.routeChunks,
    this.routeVersion,
    this.chunks = const <int, List<SharedRoutePoint>>{},
  });

  /// `waiting`, `live` or `paused`.
  final String tracking;
  final SharePosition? position;

  /// The phone is still where it last said: the server stamps the time again.
  final bool confirmed;
  final double? distanceMeters;
  final int? routeChunks;
  final int? routeVersion;

  /// Whole chunks to write, by number; rewriting one is harmless.
  final Map<int, List<SharedRoutePoint>> chunks;
}

/// The owner's side of sharing. Every call here needs the server, on purpose:
/// see `FirestoreShareRepository.publish`.
abstract interface class ShareRepository {
  /// Creates the share and its owner record in one write, confirmed by the
  /// server. Throws [ShareFailure].
  Future<ShareRecord> create({
    required String uid,
    required String token,
    required ShareKind kind,
    required DateTime expiresAt,
    String? journeyId,
    SharedPlace? origin,
    SharedPlace? destination,
  });

  /// Throws [ShareGone] when the share is over, [ShareFailure] when it could
  /// not be reached. Nothing is left queued.
  Future<void> publish(String token, ShareUpdate update);

  /// Marks a journey's share finished and shortens it to [expiresAt].
  Future<void> finish(
    String uid,
    String token, {
    required DateTime expiresAt,
    required ShareUpdate last,
  });

  /// Deletes the share, its route and its record. True once the server
  /// confirmed; false when it is queued for when the connection returns.
  Future<bool> stop(String uid, String token);

  /// This account's shares, from its own records.
  Future<List<ShareRecord>> records(String uid);
}
