import 'package:safe_ride/features/journeys/data/models/escalation.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';

/// The escalation seam: the request the phone sends, and what the backend
/// made of it. `FirestoreEscalationRepository` implements it.
abstract interface class EscalationRepository {
  /// Writes the request. It is saved on the phone at once; the future
  /// completes only when the server confirms it, so it may wait for hours
  /// offline, and throws if the server refuses.
  Future<void> submit(SafetyCheck check, PotentialIncident incident);

  /// Whether the server holds the request. Throws when it cannot be asked.
  Future<bool> received(String uid, String checkId);

  /// The escalation of [checkId], live; null until the backend makes one.
  Stream<Escalation?> watch(String uid, String checkId);
}
