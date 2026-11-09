import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';

/// What `JourneyTracker` tells whoever watches its recording — today the
/// potential-incident monitor. It is handed the tracker's own fixes, so
/// nothing else subscribes to the location. Every call is synchronous and
/// must return at once: the watcher queues its own work.
abstract interface class TrackingObserver {
  /// Recording of [journeyId] began or resumed; [lastFixBefore] is the last
  /// fix of a recording the app was closed in the middle of; [destination] is
  /// where the journey was planned to end, when it was picked on the map.
  void started(
    String uid,
    String journeyId,
    DateTime at, {
    DateTime? lastFixBefore,
    IncidentPlace? destination,
  });

  /// A fix arrived (trusted or not — the watcher judges for itself).
  void fixed(String journeyId, LocationFix fix, DateTime at);

  /// The tracker's periodic tick.
  void ticked(String journeyId, DateTime at);

  /// Permission was taken away or the services turned off.
  void interrupted(String journeyId, InterruptionCause cause, DateTime at);

  /// The account signed out: recording paused, the journey still open.
  void paused(String journeyId);

  /// The journey ended (completed or cancelled): nothing more to watch.
  void ended(String uid, String journeyId, DateTime at);
}
