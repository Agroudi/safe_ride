import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/repository/location_source.dart';

/// [LocationSource] over the `geolocator` plugin.
///
/// - **Foreground permission only.** A journey is started on screen, and a
///   recording started there keeps running in the background: Android lets
///   a foreground service of type `location` (the persistent notice) keep
///   reading with the while-in-use permission, and iOS keeps a while-in-use
///   app's updates going with background location mode and the blue
///   indicator. SafeRide never asks for "all the time" access.
/// - **A fix every [interval], moving or not** ([distanceFilter] 0). A
///   distance filter would stop fixes while the phone stands still — and
///   standing still would then look exactly like losing the signal, which
///   the potential-incident detection must tell apart. The tracker stores
///   only trusted points that moved, so the route does not grow while
///   still. Battery: high accuracy is already on for the journey; only the
///   callbacks are more frequent. Nothing runs outside a journey.
///
/// The persistent notice needs the notification permission on Android 13+;
/// [requestNotices] asks for it through `firebase_messaging`, which the app
/// already uses for that permission (Profile → Notifications).
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource(this._messaging);

  final FirebaseMessaging _messaging;

  /// Metres the phone must move before it reports a new fix: none.
  static const int distanceFilter = 0;

  /// Two seconds: one or two fixes span a sudden stop (the detection's
  /// window is four).
  static const Duration interval = Duration(seconds: 2);

  @override
  Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    return _withAccuracy(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _withAccuracy(permission);
  }

  @override
  Future<void> requestNotices() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final NotificationSettings now = await _messaging.getNotificationSettings();
    if (now.authorizationStatus == AuthorizationStatus.notDetermined) {
      await _messaging.requestPermission();
    }
  }

  @override
  Stream<LocationFix> fixes({required String title, required String text}) =>
      Geolocator.getPositionStream(locationSettings: _settings(title, text))
          .map(_fix)
          .handleError(
            (Object e) => throw switch (e) {
              LocationServiceDisabledException() => const LocationSourceError(
                LocationAccess.serviceOff,
              ),
              _ => const LocationSourceError(LocationAccess.denied),
            },
            test: (Object? e) =>
                e is LocationServiceDisabledException ||
                e is PermissionDeniedException,
          );

  @override
  Future<LocationFix?> current() async {
    try {
      return _fix(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        ),
      );
    } on Object {
      return null;
    }
  }

  @override
  Stream<bool> get serviceChanges => Geolocator.getServiceStatusStream().map(
    (ServiceStatus s) => s == ServiceStatus.enabled,
  );

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<LocationAccess> _withAccuracy(LocationPermission permission) async {
    switch (permission) {
      case LocationPermission.denied || LocationPermission.unableToDetermine:
        return LocationAccess.denied;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.whileInUse || LocationPermission.always:
        return await Geolocator.getLocationAccuracy() ==
                LocationAccuracyStatus.reduced
            ? LocationAccess.approximate
            : LocationAccess.granted;
    }
  }

  static LocationSettings _settings(String title, String text) =>
      switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
          intervalDuration: interval,
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: title,
            notificationText: text,
            notificationChannelName: title,
            // The logo mark, white on transparent — a status-bar icon.
            notificationIcon: const AndroidResource(
              name: 'ic_launcher_foreground',
            ),
            setOngoing: true,
          ),
        ),
        TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
          activityType: ActivityType.otherNavigation,
          // iOS would otherwise pause updates at a red light and may not
          // resume them in the background.
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
        _ => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        ),
      };

  static LocationFix _fix(Position p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    at: p.timestamp.toUtc(),
    accuracy: p.hasAccuracy ? p.accuracy : 0,
    speed: p.hasSpeed ? p.speed : null,
    speedAccuracy: p.hasSpeedAccuracy ? p.speedAccuracy : null,
  );
}
