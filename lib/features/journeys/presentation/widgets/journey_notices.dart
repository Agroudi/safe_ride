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

  /// Started: the server has the checklist and the start — or, offline, the
  /// phone does and will send them; the notice says which.
  static AppNotification started(
    BuildContext context, {
    required bool synced,
  }) => AppNotification.success(
    title: context.tr('journeys.notices.started.title'),
    message: context.tr(
      synced
          ? 'journeys.notices.started.message'
          : 'journeys.notices.started.offline',
    ),
  );

  /// The checklist was left without starting.
  static AppNotification notStarted(BuildContext context) =>
      AppNotification.info(title: context.tr('journeys.notices.notStarted'));

  static AppNotification cancelled(BuildContext context) =>
      AppNotification.info(title: context.tr('journeys.notices.cancelled'));

  /// Review's Confirm came after the departure: back to the plan for a new
  /// time.
  static AppNotification departurePassed(BuildContext context) =>
      AppNotification.warning(
        title: context.tr('journeys.notices.departurePassed.title'),
        message: context.tr('journeys.notices.departurePassed.message'),
      );

  static AppNotification failure(
    BuildContext context,
    JourneyFailureCode code,
  ) => AppNotification.error(
    title: context.tr('journeys.errors.title'),
    message: context.tr(messageKey(code)),
  );

  /// [code]'s sentence — in a notice, or on a screen that cannot go on.
  static String messageKey(JourneyFailureCode code) => switch (code) {
    JourneyFailureCode.signedOut => 'journeys.errors.signedOut',
    JourneyFailureCode.notPlanned => 'journeys.errors.notPlanned',
    JourneyFailureCode.alreadyStarted => 'journeys.errors.alreadyStarted',
    JourneyFailureCode.notStarted => 'journeys.errors.notStarted',
    JourneyFailureCode.checklistIncomplete =>
      'journeys.errors.checklistIncomplete',
    JourneyFailureCode.network => 'journeys.errors.network',
    JourneyFailureCode.notFound ||
    JourneyFailureCode.storage => 'journeys.errors.storage',
  };
}
