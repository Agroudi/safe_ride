import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';

const String _safeAction = 'safe';
const String _iosCategory = 'safety_check';
const String _port = 'safe_ride/safety_answers';

/// Records an "I'm safe" tap and tells the app, if it is running.
Future<void> _record(NotificationResponse response) async {
  final String? id = response.payload;
  if (response.actionId != _safeAction || id == null) return;
  await SafetyAnswerInbox().put(id, DateTime.now().toUtc());
  IsolateNameServer.lookupPortByName(_port)?.send(null);
}

/// A notification action, run in its own isolate: no service locator, and
/// no widgets. It must stay top-level for the plugin to find it.
@pragma('vm:entry-point')
Future<void> safetyNotificationAction(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await _record(response);
}

/// [SafetyNotifications] as local notifications.
///
/// - **One id**, so a safety check is never shown twice: a new notification
///   replaces the last one.
/// - **Android:** the highest importance a channel can ask for, category
///   `alarm`, public on the lock screen (the text says nothing private) —
///   whether it actually shows there is the phone's setting. The countdown
///   is the system's own chronometer, and `timeoutAfter` removes the
///   notification at the deadline even if the app has been killed. No
///   full-screen intent: Android reserves it for calls and alarm clocks,
///   and a stores' declaration SafeRide could not justify.
/// - **iOS:** time-sensitive where the capability is enabled; there is no
///   countdown (the text cannot change while the app is suspended).
class LocalSafetyNotifications implements SafetyNotifications {
  LocalSafetyNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    this.contactAlerts = AppFeatures.contactAlerts,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Whether this build can receive a contact's alert.
  final bool contactAlerts;

  static const int _id = 7001;
  static const String _channel = 'safety_check';

  /// The channel a trusted contact's alert arrives on (`functions/src`).
  static const String _alertsChannel = 'trusted_contact_alerts';

  /// Drawn white on transparent, like the recording's notice.
  static const String _icon = 'ic_launcher_foreground';

  final FlutterLocalNotificationsPlugin _plugin;
  final SafetyAnswerInbox _inbox = SafetyAnswerInbox();
  final StreamController<void> _answered = StreamController<void>.broadcast();
  Future<void>? _ready;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Stream<void> get answered => _answered.stream;

  @override
  Future<void> prepare() => _ready ??= _initialize();

  Future<void> _initialize() async {
    final ReceivePort answers = ReceivePort();
    IsolateNameServer.removePortNameMapping(_port);
    IsolateNameServer.registerPortWithName(answers.sendPort, _port);
    answers.listen((_) => _answered.add(null));

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(_icon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              _iosCategory,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  _safeAction,
                  'journeys.safetyCheck.safe'.tr(),
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _record,
      onDidReceiveBackgroundNotificationResponse: safetyNotificationAction,
    );
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channel,
        'journeys.safetyCheck.notice.channel'.tr(),
        description: 'journeys.safetyCheck.notice.channelBody'.tr(),
        importance: Importance.max,
      ),
    );
    if (!contactAlerts) return;
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        _alertsChannel,
        'safety.alerts.channel'.tr(),
        description: 'safety.alerts.channelBody'.tr(),
        importance: Importance.max,
      ),
    );
  }

  AndroidNotificationDetails _androidDetails({
    required Duration left,
    required DateTime? deadline,
    List<AndroidNotificationAction>? actions,
  }) => AndroidNotificationDetails(
    _channel,
    'journeys.safetyCheck.notice.channel'.tr(),
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    onlyAlertOnce: true,
    when: deadline?.millisecondsSinceEpoch,
    showWhen: deadline != null,
    usesChronometer: deadline != null,
    chronometerCountDown: deadline != null,
    timeoutAfter: deadline == null ? null : left.inMilliseconds,
    actions: actions,
  );

  @override
  Future<void> asking(SafetyCheck check) async {
    await prepare();
    final Duration left = check.deadline.difference(DateTime.now().toUtc());
    if (left.isNegative) return;
    await _plugin.show(
      id: _id,
      title: 'journeys.safetyCheck.title'.tr(),
      body: 'journeys.safetyCheck.notice.body'.tr(),
      payload: check.id,
      notificationDetails: NotificationDetails(
        android: _androidDetails(
          left: left,
          deadline: check.deadline,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _safeAction,
              'journeys.safetyCheck.safe'.tr(),
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _iosCategory,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  @override
  Future<void> noAnswer() async {
    await prepare();
    await _plugin.show(
      id: _id,
      title: 'journeys.safetyCheck.noAnswer.title'.tr(),
      body: 'journeys.safetyCheck.notice.noAnswer'.tr(),
      notificationDetails: NotificationDetails(
        android: _androidDetails(left: Duration.zero, deadline: null),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> clear() async {
    await prepare();
    await _plugin.cancel(id: _id);
  }

  @override
  Future<SafetyNoticeAccess> access() async {
    await prepare();
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android != null) {
      if (await android.areNotificationsEnabled() != true) {
        return SafetyNoticeAccess.blocked;
      }
      for (final AndroidNotificationChannel c
          in await android.getNotificationChannels() ??
              const <AndroidNotificationChannel>[]) {
        if (c.id == _channel && c.importance == Importance.none) {
          return SafetyNoticeAccess.blocked;
        }
      }
      return SafetyNoticeAccess.allowed;
    }
    final NotificationsEnabledOptions? ios = await _ios?.checkPermissions();
    return ios?.isAlertEnabled == true
        ? SafetyNoticeAccess.allowed
        : SafetyNoticeAccess.blocked;
  }

  @override
  Future<SafetyNoticeAccess> request() async {
    await prepare();
    await _android?.requestNotificationsPermission();
    await _ios?.requestPermissions(alert: true, sound: true);
    return access();
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<Map<String, DateTime>> takeAnswers() async {
    try {
      return await _inbox.take();
    } on Object catch (e) {
      debugPrint('Safety answers: could not be read (${e.runtimeType})');
      return <String, DateTime>{};
    }
  }
}
