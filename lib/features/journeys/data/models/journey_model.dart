import 'package:freezed_annotation/freezed_annotation.dart';

part 'journey_model.freezed.dart';
part 'journey_model.g.dart';

/// Where a journey stands. The user sets every change — SafeRide does not
/// track a journey, so there is deliberately no "in progress": a status that
/// suggests someone is watching over a trip would be false reassurance.
enum JourneyStatus {
  /// Confirmed after review; not yet over.
  planned,

  /// The user said they arrived.
  completed,

  /// The user called it off.
  cancelled,
}

/// One journey the user planned on this phone. Places are the user's own
/// words — no geocoding, no coordinates.
@freezed
abstract class JourneyModel with _$JourneyModel {
  const factory JourneyModel({
    required String id,
    required String origin,
    required String destination,
    required JourneyStatus status,

    /// UTC.
    required DateTime createdAt,

    /// UTC; the last change (an edit or a status).
    required DateTime updatedAt,

    /// UTC; when the user means to set off. Every journey planned from
    /// batch 4 on has one; null only on a journey stored before the field
    /// existed — shown as "not set", never guessed.
    DateTime? departsAt,
  }) = _JourneyModel;

  factory JourneyModel.fromJson(Map<String, dynamic> json) =>
      _$JourneyModelFromJson(json);
}
