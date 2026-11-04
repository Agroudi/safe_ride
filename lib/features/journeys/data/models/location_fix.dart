/// One position as the phone reported it, before SafeRide decides whether to
/// trust it (`RouteFilter`). Never stored as it is.
final class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.at,
    required this.accuracy,
    this.speed,
    this.speedAccuracy,
  });

  final double latitude;
  final double longitude;

  /// When the phone took the fix (UTC).
  final DateTime at;

  /// Horizontal accuracy in metres (radius); 0 or less when unknown.
  final double accuracy;

  /// Metres per second, when the phone measured it.
  final double? speed;

  /// Metres per second, when the phone says how far [speed] can be off.
  final double? speedAccuracy;
}

/// Whether SafeRide may read the location right now.
enum LocationAccess {
  /// Precise location, while the app is in use (enough for a journey: the
  /// recording keeps running in the background from there — see
  /// `JourneyTracker`).
  granted,

  /// Allowed, but only the approximate location (Android 12+, iOS 14+):
  /// kilometres off, useless for a route, speed or distance.
  approximate,

  /// Not allowed yet; asking again shows the system prompt.
  denied,

  /// Refused for good: only the system settings can change it.
  deniedForever,

  /// The phone's location services are off.
  serviceOff,
}
