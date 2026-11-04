import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/session/session_reader.dart';

/// Whether this phone lets SafeRide show notifications.
enum PushPermission {
  allowed,

  /// Never asked — asking is still possible.
  notAsked,

  /// Refused; only the phone's settings can change it.
  blocked,
}

/// What signing out needs from push: forget this install, so the next
/// account on the phone never receives the last one's notifications.
abstract interface class DeviceRegistration {
  Future<void> unregister();
}

/// Firebase Cloud Messaging, the receiving end (docs/firebase-architecture.md
/// §7.1). The backend sends one thing: a trusted contact's alert.
///
/// - **Permission** is asked only when the user taps the Profile row, never
///   at launch.
/// - **This install's FCM id** — the Firebase Installation ID that
///   `register()` reports on `onRegistered`, which a server uses to send to
///   this phone — is kept at `users/{uid}/devices/{installId}` while someone
///   is signed in and the permission is granted. Signing out deletes it and
///   unregisters the install.
/// - **Foreground** messages show as the app's own notification card.
/// - **Opened** messages (from the background or a cold start) go to an
///   allowlisted route once a signed-in tab is on screen.
/// - **Background** messages: `pushBackgroundHandler`.
///
/// Sending happens only on a server; the app holds no server key.
class PushNotifications implements DeviceRegistration, AccountData {
  PushNotifications({
    required FirebaseMessaging messaging,
    required FirebaseFirestore db,
    required SessionReader session,
    required AppNotifier notifier,
    required Future<String> Function() installId,
    Stream<RemoteMessage>? onMessage,
    Stream<RemoteMessage>? onMessageOpened,
  }) : _messaging = messaging,
       _db = db,
       _session = session,
       _notifier = notifier,
       _installId = installId,
       _onMessage = onMessage ?? FirebaseMessaging.onMessage,
       _onMessageOpened =
           onMessageOpened ?? FirebaseMessaging.onMessageOpenedApp;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final SessionReader _session;
  final AppNotifier _notifier;
  final Future<String> Function() _installId;
  final Stream<RemoteMessage> _onMessage;
  final Stream<RemoteMessage> _onMessageOpened;
  GoRouter? _router;
  ({String name, String? id})? _pending;

  /// The account this install is registered for in this run — the session
  /// reports every profile change too, and one registration is enough.
  String? _registeredFor;

  /// Routes a notification may open — anything else opens nothing.
  static const Set<String> _routes = <String>{
    AppRoutes.home,
    AppRoutes.myJourneys,
    AppRoutes.safety,
    AppRoutes.profile,
    AppRoutes.trustedContacts,
    AppRoutes.safetyAlerts,
    AppRoutes.journey,
  };

  /// The tab roots: a signed-in screen is showing, so opening is safe.
  static const Set<String> _signedIn = <String>{
    AppRoutes.home,
    AppRoutes.myJourneys,
    AppRoutes.safety,
    AppRoutes.profile,
  };

  /// Starts listening. Called once, after the service locator, with the
  /// app's router.
  Future<void> start(GoRouter router) async {
    _router = router;
    router.routerDelegate.addListener(_openPending);
    _onMessage.listen(_foreground);
    _onMessageOpened.listen(_opened);
    _messaging.onRegistered.listen((String fid) => _save(fid));
    _session.changes.listen((_) => _register());
    final RemoteMessage? launch = await _messaging.getInitialMessage();
    if (launch != null) _opened(launch);
    await _register();
  }

  Future<PushPermission> permission() async =>
      _permissionOf(await _messaging.getNotificationSettings());

  /// Shows the system prompt (once — after a refusal the phone's settings
  /// decide) and registers this install when allowed.
  Future<PushPermission> requestPermission() async {
    final PushPermission result = _permissionOf(
      await _messaging.requestPermission(),
    );
    if (result == PushPermission.allowed) await _register();
    return result;
  }

  @override
  Future<void> erase(String uid) => unregister();

  @override
  Future<void> unregister() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) return;
    _registeredFor = null;
    try {
      await settle(_device(user.id, await _installId()).delete());
      await _messaging.unregister();
    } on Object catch (e) {
      // Offline: the record goes stale; a server-side clean-up prunes it.
      debugPrint('Push: could not unregister ($e)');
    }
  }

  /// Registers this install with FCM — when someone is signed in and
  /// notifications are allowed. Its id arrives on `onRegistered` ([_save]).
  Future<void> _register() async {
    try {
      final SessionUser? user = await _session.signedInUser();
      if (user == null) {
        _registeredFor = null;
        return;
      }
      if (_registeredFor == user.id) return;
      if (await permission() != PushPermission.allowed) return;
      await _messaging.register();
      _registeredFor = user.id;
    } on Object catch (e) {
      // iOS without an APNs key, no Play services, offline: try next time.
      debugPrint('Push: not registered ($e)');
    }
  }

  Future<void> _save(String fid) async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) return;
    await settle(
      _device(user.id, await _installId()).set(<String, Object?>{
        'fid': fid,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  DocumentReference<Map<String, dynamic>> _device(String uid, String id) =>
      _db.collection(FirestorePaths.devices(uid)).doc(id);

  void _foreground(RemoteMessage message) {
    final RemoteNotification? shown = message.notification;
    if (shown == null) return;
    final ({String name, String? id})? target = targetOf(message.data);
    _notifier.show(
      AppNotification.info(
        title: shown.title ?? 'app.name'.tr(),
        message: shown.body,
        actionLabel: target == null ? null : 'notifications.open'.tr(),
        onAction: target == null ? null : () => _go(target),
      ),
    );
  }

  void _opened(RemoteMessage message) {
    final ({String name, String? id})? target = targetOf(message.data);
    if (target != null) _go(target);
  }

  void _go(({String name, String? id}) target) {
    _pending = target;
    _openPending();
  }

  /// Opens the waiting target once a signed-in tab is on screen — never
  /// over the splash, onboarding or a sign-in screen.
  void _openPending() {
    final ({String name, String? id})? target = _pending;
    final GoRouter? router = _router;
    if (target == null || router == null) return;
    if (!_signedIn.contains(router.state.name)) return;
    _pending = null;
    final String? id = target.id;
    if (_signedIn.contains(target.name)) {
      // A tab root is a `go` destination; a push would stack a second shell.
      router.goNamed(target.name);
    } else {
      router.pushNamed(
        target.name,
        pathParameters: id == null ? const <String, String>{} : {'id': id},
      );
    }
  }

  /// A message's `route` (and `id`), if it is one a notification may open.
  static ({String name, String? id})? targetOf(Map<String, dynamic> data) {
    final Object? route = data['route'];
    if (route is! String || !_routes.contains(route)) return null;
    final Object? id = data['id'];
    if (route == AppRoutes.journey) {
      return id is String && id.isNotEmpty ? (name: route, id: id) : null;
    }
    return (name: route, id: null);
  }

  static PushPermission _permissionOf(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.allowed,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.blocked,
        AuthorizationStatus.notDetermined => PushPermission.notAsked,
      };
}
