import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';

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

  /// Call could not open the phone app; the number is still on screen.
  static AppNotification callFailed(BuildContext context, String number) =>
      AppNotification.warning(
        title: context.tr('safety.emergency.callFailed.title'),
        message: context.tr(
          'safety.emergency.callFailed.message',
          namedArgs: <String, String>{'number': number},
        ),
      );
}
