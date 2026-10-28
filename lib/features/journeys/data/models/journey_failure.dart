/// Why a journey call failed — the one error `JourneyRepository` throws.
enum JourneyFailureCode {
  /// Nobody is signed in, so there is no account to keep journeys under.
  signedOut,

  /// No journey has that id (for this account).
  notFound,

  /// The change does not apply to the journey's status — only a planned
  /// journey can be completed or cancelled.
  notPlanned,

  /// The device's storage could not be read or written.
  storage,
}

class JourneyFailure implements Exception {
  const JourneyFailure(this.code);

  final JourneyFailureCode code;

  @override
  String toString() => 'JourneyFailure(${code.name})';
}
