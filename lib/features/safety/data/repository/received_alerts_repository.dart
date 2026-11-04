import 'package:safe_ride/features/safety/data/models/received_alert.dart';

/// The alerts received as someone's trusted contact.
/// `FirestoreReceivedAlertsRepository` implements it. Read-only: the backend
/// alone writes them.
abstract interface class ReceivedAlertsRepository {
  /// Newest first. Throws `ContactFailure`.
  Future<List<ReceivedAlert>> alerts();

  /// Fires when one arrives.
  Stream<void> get changes;
}
