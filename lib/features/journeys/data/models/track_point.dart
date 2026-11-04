import 'package:freezed_annotation/freezed_annotation.dart';

part 'track_point.freezed.dart';
part 'track_point.g.dart';

/// One trusted point of a journey's route, in the order it was recorded.
/// Kept on the phone first (`TrackStore`), then sent to the account in
/// chunks (`RouteRepository`).
@freezed
abstract class TrackPoint with _$TrackPoint {
  const factory TrackPoint({
    required double lat,
    required double lng,

    /// When the phone took the fix (UTC).
    required DateTime at,

    /// Horizontal accuracy in metres.
    required double accuracy,

    /// Metres per second, only when the phone's reading was trustworthy.
    double? speed,

    /// Which unbroken stretch of the route this point belongs to: a new
    /// segment begins after the recording stopped or lost every signal for a
    /// while. No distance is counted across segments.
    @Default(0) int segment,
  }) = _TrackPoint;

  factory TrackPoint.fromJson(Map<String, dynamic> json) =>
      _$TrackPointFromJson(json);
}
