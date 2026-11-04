import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/local_safety_notifications.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';

const MethodChannel _channel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

/// What the real class asks of Android, read at the plugin's method channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  late bool enabled;
  late List<Map<String, Object?>> channels;
  late LocalSafetyNotifications notices;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = <MethodCall>[];
    enabled = true;
    channels = <Map<String, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'areNotificationsEnabled' => enabled,
            'requestNotificationsPermission' => enabled,
            'getNotificationChannels' => channels,
            _ => null,
          };
        });
    notices = LocalSafetyNotifications();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Map<Object?, Object?> shown() =>
      calls.lastWhere((MethodCall c) => c.method == 'show').arguments
          as Map<Object?, Object?>;

  Map<Object?, Object?> android() =>
      shown()['platformSpecifics']! as Map<Object?, Object?>;

  SafetyCheck check() {
    final DateTime at = DateTime.now().toUtc();
    return SafetyCheck(
      id: 'e1-check',
      incidentId: 'e1',
      journeyId: 'j1',
      uid: 'sara',
      status: SafetyCheckStatus.pending,
      startedAt: at,
      deadline: at.add(const Duration(seconds: 15)),
    );
  }

  test('with no alert backend, only the safety check has a channel', () async {
    await notices.prepare();
    final List<MethodCall> made = calls
        .where((MethodCall c) => c.method == 'createNotificationChannel')
        .toList();
    expect(made, hasLength(1));
    expect(
      (made.single.arguments as Map<Object?, Object?>)['id'],
      'safety_check',
    );
  });

  test('both channels at the highest importance, one time', () async {
    notices = LocalSafetyNotifications(contactAlerts: true);
    await notices.prepare();
    await notices.prepare();
    final List<MethodCall> made = calls
        .where((MethodCall c) => c.method == 'createNotificationChannel')
        .toList();
    expect(
      made.map((MethodCall c) => (c.arguments as Map<Object?, Object?>)['id']),
      <String>['safety_check', 'trusted_contact_alerts'],
    );
    for (final MethodCall c in made) {
      expect(
        (c.arguments as Map<Object?, Object?>)['importance'],
        Importance.max.value,
      );
    }
  });

  test('the question: a countdown, the check id, one "I\'m safe"', () async {
    final SafetyCheck c = check();
    await notices.asking(c);
    expect(shown()['id'], 7001);
    expect(shown()['payload'], 'e1-check');
    final Map<Object?, Object?> a = android();
    expect(a['channelId'], 'safety_check');
    expect(a['category'], 'alarm');
    expect(a['usesChronometer'], isTrue);
    expect(a['chronometerCountDown'], isTrue);
    expect(a['when'], c.deadline.millisecondsSinceEpoch);
    expect(a['timeoutAfter'], inInclusiveRange(1, 15000));
    expect(a['onlyAlertOnce'], isTrue);
    expect(a['fullScreenIntent'], isFalse);
    final List<Object?> actions = a['actions']! as List<Object?>;
    expect(actions, hasLength(1));
    final Map<Object?, Object?> safe = actions.single! as Map<Object?, Object?>;
    expect(safe['id'], 'safe');
    expect(safe['showsUserInterface'], isFalse);
  });

  test('nothing is posted for a deadline already gone', () async {
    final DateTime past = DateTime.now().toUtc().subtract(
      const Duration(seconds: 1),
    );
    await notices.asking(check().copyWith(deadline: past));
    expect(calls.where((MethodCall c) => c.method == 'show'), isEmpty);
  });

  test('"no answer" replaces it: same id, no countdown, no action', () async {
    await notices.noAnswer();
    expect(shown()['id'], 7001);
    final Map<Object?, Object?> a = android();
    expect(a['usesChronometer'], isFalse);
    expect(a['timeoutAfter'], isNull);
    expect(a['actions'], anyOf(isNull, isEmpty));
  });

  test('clear cancels that id', () async {
    await notices.clear();
    final MethodCall cancel = calls.singleWhere(
      (MethodCall c) => c.method == 'cancel',
    );
    expect((cancel.arguments as Map<Object?, Object?>)['id'], 7001);
  });

  test('refused notifications are blocked', () async {
    enabled = false;
    expect(await notices.access(), SafetyNoticeAccess.blocked);
  });

  test('allowed', () async {
    expect(await notices.access(), SafetyNoticeAccess.allowed);
  });

  test('the safety channel switched off in settings is blocked', () async {
    channels = <Map<String, Object?>>[
      <String, Object?>{
        'id': 'safety_check',
        'name': 'x',
        'description': '',
        'groupId': null,
        'showBadge': true,
        'importance': Importance.none.value,
        'playSound': false,
        'enableVibration': false,
        'vibrationPattern': null,
        'enableLights': false,
        'bypassDnd': false,
        'ledColor': 0,
        'audioAttributesUsage': AudioAttributesUsage.notification.value,
        'sound': null,
        'soundSource': null,
      },
    ];
    expect(await notices.access(), SafetyNoticeAccess.blocked);
  });
}
