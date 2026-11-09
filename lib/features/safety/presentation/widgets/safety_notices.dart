import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/invite_failure.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';

/// The safety feature's notifications, translated when shown. A duplicate
/// number is a field error, not a notification.
abstract final class SafetyNotices {
  static AppNotification contact(BuildContext context, String key) =>
      AppNotification.success(
        title: context.tr('safety.contacts.notices.$key'),
      );

  static AppNotification failure(
    BuildContext context,
    ContactFailureCode code,
  ) => AppNotification.error(
    title: context.tr('safety.contacts.errors.title'),
    message: context.tr('safety.contacts.errors.${code.name}'),
  );

  static AppNotification invite(BuildContext context, InviteFailureCode code) =>
      AppNotification.error(
        title: context.tr('safety.invite.errors.title'),
        message: context.tr('safety.invite.errors.${code.name}'),
      );

  /// Shows what a Call came to; nothing for an ignored duplicate tap.
  static void showDial(
    BuildContext context,
    DialOutcome? outcome,
    String number,
  ) {
    if (outcome == null || !context.mounted) return;
    sl<AppNotifier>().show(dial(context, outcome, number));
  }

  /// What opening the phone app with [number] came to. "Opened" never
  /// says the call was made: SafeRide cannot see that.
  static AppNotification dial(
    BuildContext context,
    DialOutcome outcome,
    String number,
  ) {
    final String key = 'safety.emergency.dial.${outcome.name}';
    final String message = context.tr(
      '$key.message',
      namedArgs: <String, String>{'number': number},
    );
    return switch (outcome) {
      DialOutcome.opened => AppNotification.info(
        title: context.tr('$key.title'),
        message: message,
      ),
      DialOutcome.noDialer || DialOutcome.failed => AppNotification.warning(
        title: context.tr('$key.title'),
        message: message,
      ),
      DialOutcome.invalidNumber => AppNotification.error(
        title: context.tr('$key.title'),
        message: message,
      ),
    };
  }

  /// Shows what a Message came to; nothing for an ignored duplicate tap.
  static void showCompose(
    BuildContext context,
    ComposeOutcome? outcome,
    String name,
  ) {
    if (outcome == null || !context.mounted) return;
    sl<AppNotifier>().show(compose(context, outcome, name));
  }

  /// What opening the messaging app to [name] came to. "Opened" never says
  /// the message was sent: the user sends it, and SafeRide cannot see that.
  static AppNotification compose(
    BuildContext context,
    ComposeOutcome outcome,
    String name,
  ) {
    final String key = 'safety.reach.compose.${outcome.name}';
    final String title = context.tr('$key.title');
    final String message = context.tr(
      '$key.message',
      namedArgs: <String, String>{'name': name},
    );
    return switch (outcome) {
      ComposeOutcome.opened => AppNotification.info(
        title: title,
        message: message,
      ),
      ComposeOutcome.noMessaging || ComposeOutcome.failed =>
        AppNotification.warning(title: title, message: message),
      ComposeOutcome.invalidNumber => AppNotification.error(
        title: title,
        message: message,
      ),
    };
  }
}
