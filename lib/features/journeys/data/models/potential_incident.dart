import 'package:freezed_annotation/freezed_annotation.dart';

part 'potential_incident.freezed.dart';
part 'potential_incident.g.dart';

/// What kind of unusual movement was noticed. None of them is proof of an
/// accident.
enum IncidentType {
  /// A fast drop from driving speed to standing still that lasted.
  suddenDeceleration,

  /// Standing still unusually long during a journey that had been moving.
  prolongedStop,

  /// Reliable tracking stopped; [InterruptionCause] says why when known.
  /// Never treated as an incident of movement.
  trackingInterrupted,
}

/// Where an event is in its life.
enum IncidentStatus {
  /// Noticed and still open.
  detected,

  /// A safety check is asking the user about it (`SafetyCheck`). The
  /// detection no longer resolves or replaces it; the check decides.
  awaitingConfirmation,

  /// The user did not answer its safety check in time: reported to the
  /// backend. Not a confirmed accident — only no answer.
  escalationReady,

  /// The user said they are fine.
  dismissed,

  /// The condition ended (movement resumed, tracking restored, journey
  /// ended).
  resolved,

  /// A newer event about the same thing replaced it.
  superseded,
}

/// How much the data supports the event — never certainty.
enum IncidentConfidence { low, medium, high }

/// Why tracking stopped, when it could be told.
enum InterruptionCause {
  /// Location permission was taken away.
  permissionRemoved,

  /// The phone's location services were turned off.
  locationServicesOff,

  /// Permission and services were on, but no usable fix came.
  signalLost,

  /// The app was paused by the system (its timers did not run).
  appSuspended,

  /// The app was not running at all until it was opened again.
  appClosed,
}

/// Why an event closed.
enum IncidentResolution {
  movementResumed,
  trackingRestored,
  journeyEnded,
  dismissedByUser,
  replaced,

  /// The user answered its safety check: "I'm safe".
  confirmedSafe,

  /// Its safety check was cancelled (the journey ended, the account signed
  /// out) before an answer.
  checkCancelled,
}

/// One potential-incident event, kept on the phone for the next batch's
/// safety check. Its location is rounded to about 10 m — what finding
/// someone needs, not their exact spot.
@freezed
abstract class PotentialIncident with _$PotentialIncident {
  const factory PotentialIncident({
    required String id,
    required String journeyId,
    required String uid,
    required IncidentType type,
    required IncidentStatus status,
    required IncidentConfidence confidence,

    /// When it was noticed (UTC).
    required DateTime detectedAt,
    required DateTime updatedAt,

    /// A short technical account of what the data showed (logs, not UI).
    required String reason,

    /// km/h before and after a sudden deceleration; at detection for a stop.
    double? speedBeforeKmh,
    double? speedAfterKmh,

    /// m/s², for a sudden deceleration.
    double? deceleration,

    /// How long the stop or the interruption had lasted when noticed.
    int? durationSeconds,
    double? lat,
    double? lng,

    /// The fix's accuracy (metres) and how old it was (seconds) when used.
    double? accuracyMeters,
    double? fixAgeSeconds,
    InterruptionCause? interruption,
    IncidentResolution? resolution,
    String? supersededBy,
  }) = _PotentialIncident;

  factory PotentialIncident.fromJson(Map<String, dynamic> json) =>
      _$PotentialIncidentFromJson(json);
}
