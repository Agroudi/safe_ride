import 'package:firebase_messaging/firebase_messaging.dart';

/// Runs when a message arrives while the app is in the background or closed
/// — in its own isolate, with no UI. Registered in `main`.
///
/// It does nothing, on purpose: a trusted contact's alert carries a
/// notification, which the system shows without it, and no SafeRide feature
/// sends data-only messages. When one does, its work goes here (and must not
/// assume the app's service locator or widgets exist).
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {}
