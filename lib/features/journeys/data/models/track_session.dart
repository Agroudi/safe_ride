import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';

part 'track_session.freezed.dart';
part 'track_session.g.dart';

/// The recording of one journey's route by one account, kept on the phone
/// beside its points. There is never more than one per journey.
@freezed
abstract class TrackSession with _$TrackSession {
  const factory TrackSession({
    required String journeyId,
    required String uid,

    /// True while the journey is in progress and should be recorded —
    /// including while the recording is interrupted (no permission, the app
    /// closed), so it resumes; false once the journey ended.
    required bool recording,

    /// When the first recording began (UTC).
    required DateTime startedAt,

    /// The journey ended and the recording with it (UTC).
    DateTime? stoppedAt,

    /// Metres between consecutive trusted points of the same segment.
    @Default(0) double distanceMeters,

    /// How many points are stored; and how many of them the account has.
    @Default(0) int pointCount,
    @Default(0) int syncedCount,

    /// The account has the final summary (recording over).
    @Default(false) bool finalSynced,

    /// The current segment (see `TrackPoint.segment`).
    @Default(0) int segment,

    /// The last trusted point, to measure the next one from.
    TrackPoint? last,

    /// The last fix of any quality (UTC): a gap in fixes starts a segment.
    DateTime? lastFixAt,
  }) = _TrackSession;

  const TrackSession._();

  factory TrackSession.fromJson(Map<String, dynamic> json) =>
      _$TrackSessionFromJson(json);

  /// Nothing is left to send to the account.
  bool get settled => syncedCount >= pointCount && (recording || finalSynced);
}
