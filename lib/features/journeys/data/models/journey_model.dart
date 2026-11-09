import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:safe_ride/core/firebase/timestamp_converter.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';

part 'journey_model.freezed.dart';
part 'journey_model.g.dart';

/// Where a journey stands. The user sets every change; nothing tracks the
/// journey, so `active` means only "the user started it" — never that
/// anyone watches over the trip.
enum JourneyStatus {
  /// Confirmed after review; not started yet.
  planned,

  /// Started, after its pre-journey safety checklist was confirmed.
  active,

  /// The user said they arrived.
  completed,

  /// The user called it off.
  cancelled;

  /// Still open: it can be cancelled, and it is not history yet.
  bool get isOpen => this == planned || this == active;
}

/// One journey the user planned, stored in their account
/// (`users/{uid}/journeys/{id}`, docs/firebase-architecture.md §5.3).
/// [origin] and [destination] are always the user's own words; the map adds
/// where they are when it knows. A journey from before maps simply has none.
@freezed
abstract class JourneyModel with _$JourneyModel {
  const factory JourneyModel({
    required String id,
    required String origin,
    required String destination,
    required JourneyStatus status,

    /// UTC; when the user means to set off.
    @TimestampConverter() required DateTime departsAt,

    /// UTC; set by the server when the journey is saved.
    @TimestampConverter() required DateTime createdAt,

    /// UTC; the last change (an edit or a status), set by the server.
    @TimestampConverter() required DateTime updatedAt,

    /// UTC; when the user started it, set by the server. Null until then.
    @NullableTimestampConverter() DateTime? startedAt,

    /// Where the journey starts and ends, when picked on the map.
    @JourneyPlaceConverter() JourneyPlace? originPlace,
    @JourneyPlaceConverter() JourneyPlace? destinationPlace,

    /// The routing provider's estimate when it was planned, if it had one.
    double? plannedDistanceMeters,
    double? plannedDurationSeconds,
  }) = _JourneyModel;

  factory JourneyModel.fromJson(Map<String, dynamic> json) =>
      _$JourneyModelFromJson(json);
}
