/// Whether SafeRide may read the location now.
enum PositionAccess {
  allowed,

  /// Only the approximate location (Android 12+, iOS 14+): kilometres off.
  approximate,
  notAllowed,

  /// The phone's location services are off.
  servicesOff,
}

/// How old a reading is, judged when it is shown.
enum PositionFreshness {
  /// Within [PositionReading.currentFor]: where the phone is now.
  current,

  /// Older: where the phone was, and labelled so.
  lastKnown,

  /// Older than [PositionReading.staleAfter]: may be far from here.
  stale,
}

/// How far a reading can be off.
enum PositionAccuracy {
  /// Within [PositionReading.goodWithin] metres.
  good,
  rough,

  /// Over [PositionReading.poorBeyond] metres.
  poor,

  /// The phone did not say.
  unknown,
}

/// One position the phone reported, as the emergency screens show it. Read
/// on this phone, for the user's own eyes: nothing here is ever sent.
final class PositionReading {
  const PositionReading({
    required this.latitude,
    required this.longitude,
    required this.at,
    this.accuracy,
  });

  /// Matches the live map's "Use my location": a fix this fresh is where the
  /// phone is now (CLAUDE.md §16, Maps).
  static const Duration currentFor = Duration(seconds: 20);

  /// Past this, the phone may have moved far: said out loud.
  static const Duration staleAfter = Duration(minutes: 5);

  static const double goodWithin = 20;
  static const double poorBeyond = 100;

  final double latitude;
  final double longitude;

  /// When the phone took it (UTC).
  final DateTime at;

  /// Metres (radius), when the phone said.
  final double? accuracy;

  /// A position that exists on Earth, and is not the 0,0 a broken fix gives.
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);

  Duration age(DateTime now) {
    final Duration d = now.toUtc().difference(at.toUtc());
    return d.isNegative ? Duration.zero : d;
  }

  /// A fix stamped this far ahead of the phone's clock means the two
  /// disagree, and its real age cannot be known.
  static const Duration clockSkew = Duration(seconds: 2);

  PositionFreshness freshness(DateTime now) {
    // Never "current" on a clock that cannot be trusted.
    if (at.toUtc().isAfter(now.toUtc().add(clockSkew))) {
      return PositionFreshness.lastKnown;
    }
    final Duration a = age(now);
    if (a <= currentFor) return PositionFreshness.current;
    return a <= staleAfter
        ? PositionFreshness.lastKnown
        : PositionFreshness.stale;
  }

  PositionAccuracy get quality {
    final double? m = accuracy;
    if (m == null || m <= 0 || !m.isFinite) return PositionAccuracy.unknown;
    if (m <= goodWithin) return PositionAccuracy.good;
    return m <= poorBeyond ? PositionAccuracy.rough : PositionAccuracy.poor;
  }
}

/// What the emergency screens may show about where the user is: whether
/// location can be read, the latest reading if any, and the journey in
/// progress if any.
final class EmergencyPosition {
  const EmergencyPosition({
    required this.access,
    this.reading,
    this.destination,
  });

  final PositionAccess access;
  final PositionReading? reading;

  /// The destination of the journey in progress, in the user's own words.
  final String? destination;
}

/// Where the user is, for their own eyes, during an emergency. The journeys
/// feature implements it over the one recording (`JourneyTracker` stays the
/// only source of GPS); the safety feature reads it. **It never asks for
/// permission and never sends anything.**
abstract interface class EmergencyPositionReader {
  /// What is already known: the latest fix the phone gave, with no new
  /// reading taken.
  Future<EmergencyPosition> lastKnown();

  /// One reading now, on the user's tap — only when location is allowed.
  Future<EmergencyPosition> locateNow();
}
