import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';

/// Sharing's words, in one place.
abstract final class ShareLabels {
  static String duration(BuildContext context, ShareDuration d) =>
      context.tr('sharing.duration.${d.name}');

  static String delivery(BuildContext context, ShareDelivery d) =>
      context.tr('sharing.delivery.${d.name}');

  static Color deliveryTone(AppColors colors, ShareDelivery d) => switch (d) {
    ShareDelivery.reaching => colors.success,
    ShareDelivery.waiting => colors.info,
    ShareDelivery.notReaching || ShareDelivery.paused => colors.warning,
  };

  static String liveness(BuildContext context, SharedViewLabel label) =>
      context.tr('sharing.view.status.${label.name}');

  static Color livenessTone(AppColors colors, SharedViewLabel label) =>
      switch (label) {
        SharedViewLabel.live => colors.success,
        SharedViewLabel.waiting || SharedViewLabel.finished => colors.info,
        SharedViewLabel.paused ||
        SharedViewLabel.stale ||
        SharedViewLabel.offline => colors.warning,
      };

  static AppNotification failure(BuildContext context, ShareFailureCode code) =>
      AppNotification.error(
        title: context.tr('sharing.failed.${code.name}.title'),
        message: context.tr('sharing.failed.${code.name}.body'),
      );

  static AppNotification stopped(
    BuildContext context, {
    required bool confirmed,
  }) => AppNotification.info(
    title: context.tr('sharing.stopped.title'),
    message: context.tr(
      confirmed ? 'sharing.stopped.body' : 'sharing.stopped.offline',
    ),
  );
}

/// What a recipient reads as the status: [SharedLiveness], with being offline
/// told apart from an old position.
enum SharedViewLabel {
  waiting,
  live,
  paused,
  stale,
  offline,
  finished;

  static SharedViewLabel of(SharedLiveness liveness, {required bool offline}) =>
      switch (liveness) {
        SharedLiveness.finished => finished,
        SharedLiveness.waiting => waiting,
        SharedLiveness.live => live,
        SharedLiveness.paused => paused,
        SharedLiveness.stale => offline ? SharedViewLabel.offline : stale,
      };
}
