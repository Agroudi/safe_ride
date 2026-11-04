import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';

/// Where the recording of the tracked journey stands.
enum TrackingStatus {
  /// Recording, waiting for the first fix.
  starting,

  /// Fresh fixes, accurate enough to trust.
  active,

  /// Fresh fixes, but too inaccurate to trust fully.
  weakSignal,

  /// No fix for a while (indoors, a tunnel, the GPS off).
  noSignal,

  /// Location permission is missing or was taken away.
  permissionRequired,

  /// Only the approximate location is allowed.
  preciseOff,

  /// The phone's location services are off.
  locationOff,
}

/// How the route stands with the account.
enum RouteSync {
  /// Nothing recorded yet.
  none,

  /// Points recorded since the last chunk wait on this phone for the next
  /// one (every few minutes) — nothing is wrong.
  queued,

  /// A chunk is on its way.
  syncing,

  /// The account has every recorded point.
  synced,

  /// Saved on this phone; the account gets it when the connection returns.
  pending,

  /// The last attempt failed; it is tried again.
  failed,
}

/// A speed worth showing, and how fresh it is.
final class SpeedReading extends Equatable {
  const SpeedReading.current(double this.metresPerSecond, DateTime this.at)
    : current = true;

  const SpeedReading.lastKnown(double this.metresPerSecond, DateTime this.at)
    : current = false;

  const SpeedReading.unavailable()
    : metresPerSecond = null,
      at = null,
      current = false;

  final double? metresPerSecond;
  final DateTime? at;

  /// Measured within the last few seconds; otherwise the last known one.
  final bool current;

  double? get kmh => metresPerSecond == null ? null : metresPerSecond! * 3.6;

  @override
  List<Object?> get props => <Object?>[metresPerSecond, at, current];
}

/// What `JourneyTracker` reports about the journey it records.
final class TrackingSnapshot extends Equatable {
  const TrackingSnapshot({
    required this.journeyId,
    required this.status,
    required this.startedAt,
    this.speed = const SpeedReading.unavailable(),
    this.distanceMeters = 0,
    this.last,
    this.sync = RouteSync.none,
  });

  final String journeyId;
  final TrackingStatus status;
  final DateTime startedAt;
  final SpeedReading speed;
  final double distanceMeters;

  /// The latest trusted point — the current location when it is fresh.
  final TrackPoint? last;
  final RouteSync sync;

  TrackingSnapshot copyWith({
    TrackingStatus? status,
    SpeedReading? speed,
    double? distanceMeters,
    TrackPoint? last,
    RouteSync? sync,
  }) => TrackingSnapshot(
    journeyId: journeyId,
    status: status ?? this.status,
    startedAt: startedAt,
    speed: speed ?? this.speed,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    last: last ?? this.last,
    sync: sync ?? this.sync,
  );

  @override
  List<Object?> get props => <Object?>[
    journeyId,
    status,
    startedAt,
    speed,
    distanceMeters,
    last,
    sync,
  ];
}

/// What the account keeps about a journey's route
/// (`users/{uid}/journeys/{id}/tracking/summary`).
final class RouteSummary extends Equatable {
  const RouteSummary({
    required this.distanceMeters,
    required this.pointCount,
    required this.recording,
    this.firstAt,
    this.lastAt,
  });

  final double distanceMeters;
  final int pointCount;
  final bool recording;
  final DateTime? firstAt;
  final DateTime? lastAt;

  @override
  List<Object?> get props => <Object?>[
    distanceMeters,
    pointCount,
    recording,
    firstAt,
    lastAt,
  ];
}
