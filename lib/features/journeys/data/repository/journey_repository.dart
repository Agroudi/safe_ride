import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// The journeys seam: home, My Journeys and the planning screens ask this,
/// never a storage client. `LocalJourneyRepository` keeps them on the phone
/// today; a Firebase implementation replaces it behind the same interface —
/// one line in the service locator. Every method throws only
/// `JourneyFailure`, and works on the signed-in account's journeys.
abstract interface class JourneyRepository {
  /// Newest first.
  Future<List<JourneyModel>> journeys();

  /// One journey, or null when the account has none with [id].
  Future<JourneyModel?> journey(String id);

  /// Saves a confirmed plan as [JourneyStatus.planned].
  Future<JourneyModel> plan({
    required String origin,
    required String destination,
    required DateTime departsAt,
  });

  /// Changes a planned journey's places and departure. Throws `notPlanned`
  /// once it is completed or cancelled — a closed journey is a record.
  Future<JourneyModel> update(
    String id, {
    required String origin,
    required String destination,
    required DateTime departsAt,
  });

  /// planned → completed. Throws `notPlanned` from any other status.
  Future<JourneyModel> complete(String id);

  /// planned → cancelled. Throws `notPlanned` from any other status.
  Future<JourneyModel> cancel(String id);

  /// Fires after every change made through this repository, so open screens
  /// reload.
  Stream<void> get changes;
}
