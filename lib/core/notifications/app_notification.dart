import 'package:flutter/foundation.dart';
import 'package:safe_ride/core/constants/app_constants.dart';

/// What a notification is about. It picks the icon, the outline colour and
/// the word a screen reader says first — status is never colour alone.
enum AppNotificationKind { success, error, warning, info, offline }

/// One message for the `NotificationHost`, shown with `AppNotifier.show`.
///
/// The page supplies the strings, already translated. [duration] null means
/// it stays until dismissed; a screen reader user always gets that, whatever
/// the duration (`NotificationHost`).
@immutable
class AppNotification {
  const AppNotification({
    required this.kind,
    required this.title,
    this.message,
    this.duration,
    this.actionLabel,
    this.onAction,
    String? id,
  }) : _id = id;

  /// Confirmations: gone after `AppDurations.noticeShort`.
  const AppNotification.success({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    String? id,
  }) : kind = AppNotificationKind.success,
       duration = AppDurations.noticeShort,
       _id = id;

  /// Something did not work: long enough to read (`noticeLong`), and
  /// dismissible.
  const AppNotification.error({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    String? id,
  }) : kind = AppNotificationKind.error,
       duration = AppDurations.noticeLong,
       _id = id;

  const AppNotification.warning({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    String? id,
  }) : kind = AppNotificationKind.warning,
       duration = AppDurations.noticeLong,
       _id = id;

  const AppNotification.info({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    String? id,
  }) : kind = AppNotificationKind.info,
       duration = AppDurations.noticeShort,
       _id = id;

  /// No connection: stays until the connection is back and the caller
  /// dismisses it by [id] — one per outage, never a stream.
  const AppNotification.offline({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    String? id,
  }) : kind = AppNotificationKind.offline,
       duration = null,
       _id = id;

  final AppNotificationKind kind;
  final String title;

  /// A line under the title; null for a one-line notice.
  final String? message;
  final Duration? duration;

  /// An optional single action (a text button under the message). Tapping
  /// it also dismisses the notification.
  final String? actionLabel;
  final VoidCallback? onAction;

  final String? _id;

  /// Two notifications with the same id are the same message: showing it
  /// again refreshes the one on screen instead of stacking a copy. Defaults
  /// to the kind, title and message.
  String get id => _id ?? '${kind.name}|$title|${message ?? ''}';
}
