import 'package:safe_ride/features/journeys/data/models/location_fix.dart';

/// The phone's location: permission, services and fixes. The tracker asks
/// this, never a plugin; `GeolocatorLocationSource` implements it.
abstract interface class LocationSource {
  /// What SafeRide may read now — without asking anything.
  Future<LocationAccess> access();

  /// Shows the system prompt (when the system still allows one) and returns
  /// the result. Only ever called from a tap.
  Future<LocationAccess> requestAccess();

  /// One position, for choosing a place: not a subscription, no notice, and
  /// nothing recorded. Null when the phone gives none in time.
  Future<LocationFix?> current();

  /// On Android 13+, asks once for the permission that lets the
  /// recording's persistent notice show (without it Android keeps the notice
  /// out of the notification shade). Never asks twice; nothing elsewhere.
  Future<void> requestNotices();

  /// Fixes while subscribed. On Android the subscription runs as a
  /// foreground service with a notice titled [title] saying [text], so it
  /// keeps running with the screen off or another app open; on iOS it
  /// continues in the background with the system's location indicator.
  /// Emits a `LocationSourceError` when permission or the services go.
  Stream<LocationFix> fixes({required String title, required String text});

  /// The phone's location services switched on or off.
  Stream<bool> get serviceChanges;

  /// The app's page in the system settings.
  Future<void> openAppSettings();

  /// The phone's location settings.
  Future<void> openLocationSettings();
}

/// Why the fixes stopped.
class LocationSourceError implements Exception {
  const LocationSourceError(this.access);

  /// [LocationAccess.denied] / `deniedForever` / `serviceOff`.
  final LocationAccess access;
}
