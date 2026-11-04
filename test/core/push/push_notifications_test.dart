import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/push/push_notifications.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/session/session_reader.dart';

class _Session implements SessionReader {
  _Session(this.uid);

  String? uid;
  final StreamController<void> renamed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => renamed.stream;

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: status,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.notSupported,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );

/// FCM as a phone would answer: [status] until a prompt grants it, and an
/// installation id reported on every registration.
class _Messaging extends Fake implements FirebaseMessaging {
  AuthorizationStatus status = AuthorizationStatus.notDetermined;
  int registrations = 0;
  int unregistrations = 0;
  final StreamController<String> registered =
      StreamController<String>.broadcast();

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      _settings(status);

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    status = AuthorizationStatus.authorized;
    return _settings(status);
  }

  @override
  Future<void> register({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    registrations++;
    registered.add('fid-0123456789');
  }

  @override
  Future<void> unregister() async => unregistrations++;

  @override
  Stream<String> get onRegistered => registered.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}

void main() {
  late FakeFirebaseFirestore db;
  late _Messaging messaging;
  late _Session session;
  late AppNotifier notifier;
  late StreamController<RemoteMessage> foreground;
  late StreamController<RemoteMessage> opened;
  late PushNotifications push;

  setUp(() {
    db = FakeFirebaseFirestore();
    messaging = _Messaging();
    session = _Session('sara');
    notifier = AppNotifier();
    foreground = StreamController<RemoteMessage>.broadcast();
    opened = StreamController<RemoteMessage>.broadcast();
    push = PushNotifications(
      messaging: messaging,
      db: db,
      session: session,
      notifier: notifier,
      installId: () async => 'install1',
      onMessage: foreground.stream,
      onMessageOpened: opened.stream,
    );
  });

  GoRouter router({String start = '/home'}) => GoRouter(
    initialLocation: start,
    routes: <RouteBase>[
      for (final String name in <String>[
        AppRoutes.splash,
        AppRoutes.home,
        AppRoutes.myJourneys,
      ])
        GoRoute(path: '/$name', name: name, builder: (_, _) => Text(name)),
      GoRoute(
        path: '/journey/view/:id',
        name: AppRoutes.journey,
        builder: (_, GoRouterState s) =>
            Text('journey ${s.pathParameters['id']}'),
      ),
    ],
  );

  Future<Map<String, dynamic>?> device() async =>
      (await db.doc('users/sara/devices/install1').get()).data();

  test('a notification may open only allowlisted routes', () {
    expect(PushNotifications.targetOf(<String, dynamic>{'route': 'home'}), (
      name: 'home',
      id: null,
    ));
    expect(
      PushNotifications.targetOf(<String, dynamic>{
        'route': 'journey',
        'id': 'j1',
      }),
      (name: 'journey', id: 'j1'),
    );
    expect(
      PushNotifications.targetOf(<String, dynamic>{'route': 'journey'}),
      isNull,
    );
    expect(
      PushNotifications.targetOf(<String, dynamic>{'route': 'login'}),
      isNull,
    );
    expect(PushNotifications.targetOf(<String, dynamic>{}), isNull);
  });

  test('nothing registers until the user allows notifications', () async {
    await push.start(router());
    expect(messaging.registrations, 0);
    expect(await device(), isNull);
    expect(await push.permission(), PushPermission.notAsked);

    expect(await push.requestPermission(), PushPermission.allowed);
    await Future<void>.delayed(Duration.zero);
    expect(messaging.registrations, 1);
    final Map<String, dynamic>? saved = await device();
    expect(saved?['fid'], 'fid-0123456789');
    expect(saved?['platform'], 'android');
  });

  test('signed out, nothing is registered or stored', () async {
    session.uid = null;
    messaging.status = AuthorizationStatus.authorized;
    await push.start(router());
    expect(messaging.registrations, 0);
    expect(await device(), isNull);
  });

  // The session reports every profile edit too; one registration is enough.
  test('session events register the install once per account', () async {
    messaging.status = AuthorizationStatus.authorized;
    await push.start(router());
    session.renamed
      ..add(null)
      ..add(null);
    await Future<void>.delayed(Duration.zero);
    expect(messaging.registrations, 1);

    session.uid = 'omar';
    session.renamed.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(messaging.registrations, 2);
  });

  test('signing out removes this install from the account', () async {
    messaging.status = AuthorizationStatus.authorized;
    await push.start(router());
    await Future<void>.delayed(Duration.zero);
    expect(await device(), isNotNull);

    await push.unregister();
    expect(await device(), isNull);
    expect(messaging.unregistrations, 1);
  });

  test('a refusal reads as blocked', () async {
    messaging.status = AuthorizationStatus.denied;
    expect(await push.permission(), PushPermission.blocked);
  });

  test('a message in the foreground shows as the app\'s own card', () async {
    await push.start(router());
    foreground.add(
      const RemoteMessage(
        notification: RemoteNotification(title: 'Hello', body: 'World'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifier.current?.title, 'Hello');
    expect(notifier.current?.message, 'World');
  });

  testWidgets('an opened notification waits for a signed-in screen', (
    WidgetTester tester,
  ) async {
    final GoRouter app = router(start: '/${AppRoutes.splash}');
    addTearDown(app.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: app));
    await tester.runAsync(() => push.start(app));

    opened.add(
      const RemoteMessage(
        data: <String, dynamic>{'route': 'journey', 'id': 'j1'},
      ),
    );
    await tester.pumpAndSettle();
    // Never over the splash.
    expect(find.text(AppRoutes.splash), findsOneWidget);

    app.goNamed(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.text('journey j1'), findsOneWidget);
  });
}
