import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';

/// The journey screen's route recording.
sealed class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Not known yet, or nothing to record (planned, signed out).
final class TrackingIdle extends TrackingState {
  const TrackingIdle();
}

/// The journey is in progress, but SafeRide may not read the location:
/// [access] says why (and which button helps).
final class TrackingNeedsAccess extends TrackingState {
  const TrackingNeedsAccess(this.access);

  final LocationAccess access;

  @override
  List<Object?> get props => <Object?>[access];
}

/// Another journey in progress is being recorded.
final class TrackingElsewhere extends TrackingState {
  const TrackingElsewhere();
}

/// In progress, but the recording could not start (the journey could not be
/// read, or the phone's storage failed). Nothing is being recorded.
final class TrackingFailed extends TrackingState {
  const TrackingFailed();
}

/// Recording this journey.
final class TrackingLive extends TrackingState {
  const TrackingLive(this.snapshot);

  final TrackingSnapshot snapshot;

  @override
  List<Object?> get props => <Object?>[snapshot];
}

/// The journey ended; [summary] is what was recorded (null: nothing).
final class TrackingRecorded extends TrackingState {
  const TrackingRecorded(this.summary);

  final RouteSummary? summary;

  @override
  List<Object?> get props => <Object?>[summary];
}
