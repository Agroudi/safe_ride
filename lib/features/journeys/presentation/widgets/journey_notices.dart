import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';

/// The journeys feature's notifications, translated when shown.
abstract final class JourneyNotices {
  static AppNotification planned(BuildContext context) =>
      AppNotification.success(
        title: context.tr('journeys.notices.planned.title'),
        message: context.tr('journeys.notices.planned.message'),
      );

  static AppNotification updated(BuildContext context) =>
      AppNotification.success(title: context.tr('journeys.notices.updated'));

  static AppNotification completed(BuildContext context) =>
      AppNotification.success(title: context.tr('journeys.notices.completed'));

  static AppNotification cancelled(BuildContext context) =>
      AppNotification.info(title: context.tr('journeys.notices.cancelled'));

  static AppNotification failure(
    BuildContext context,
    JourneyFailureCode code,
  ) => AppNotification.error(
    title: context.tr('journeys.errors.title'),
    message: context.tr(switch (code) {
      JourneyFailureCode.signedOut => 'journeys.errors.signedOut',
      JourneyFailureCode.notPlanned => 'journeys.errors.notPlanned',
      JourneyFailureCode.notFound ||
      JourneyFailureCode.storage => 'journeys.errors.storage',
    }),
  );
}
