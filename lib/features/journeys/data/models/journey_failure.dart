/// Why a journey call failed — the one error `JourneyRepository` throws.
enum JourneyFailureCode {
  /// Nobody is signed in, so there is no account to keep journeys under.
  signedOut,

  /// No journey has that id (for this account).
  notFound,

  /// The journey is closed (completed or cancelled): it can no longer change.
  notPlanned,

  /// Only a planned journey starts or is edited, and this one already started.
  alreadyStarted,

  /// Only a started journey is marked completed.
  notStarted,

  /// The pre-journey safety checklist was not fully confirmed.
  checklistIncomplete,

  /// SafeRide's servers could not be reached, and the phone has no copy.
  network,

  /// The journey could not be read or saved (including a change the
  /// server's rules refused).
  storage,
}

class JourneyFailure implements Exception {
  const JourneyFailure(this.code);

  final JourneyFailureCode code;

  @override
  String toString() => 'JourneyFailure(${code.name})';
}
