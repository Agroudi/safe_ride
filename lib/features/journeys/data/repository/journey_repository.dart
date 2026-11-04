import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// The journeys seam: home, My Journeys and the planning screens ask this,
/// never a storage client. `FirestoreJourneyRepository` keeps them in the
/// account today; another backend would be one more implementation, chosen
/// in the service locator. Every method throws only
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

  /// Changes a planned journey's places and departure. Throws
  /// `alreadyStarted` once it started, `notPlanned` once it is closed.
  Future<JourneyModel> update(
    String id, {
    required String origin,
    required String destination,
    required DateTime departsAt,
  });

  /// planned → active, only with the pre-journey checklist for
  /// [checklistVersion] fully confirmed ([confirmed] is its item ids). The
  /// checklist record and the status change are saved together, or not at
  /// all. [synced] is false when the phone saved it but the server has not
  /// confirmed it yet (offline). Throws `checklistIncomplete`,
  /// `alreadyStarted`, `notPlanned`.
  Future<({JourneyModel journey, bool synced})> start(
    String id, {
    required int checklistVersion,
    required Set<String> confirmed,
  });

  /// active → completed. Throws `notStarted` from planned, `notPlanned` once
  /// closed.
  Future<JourneyModel> complete(String id);

  /// planned or active → cancelled. Throws `notPlanned` once closed.
  Future<JourneyModel> cancel(String id);

  /// Fires after every change made through this repository, so open screens
  /// reload.
  Stream<void> get changes;
}
