import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

/// The words of connections, in one place.
abstract final class ConnectionLabels {
  static String status(BuildContext context, ConnectionStatus status) =>
      context.tr('safety.connections.status.${status.name}');

  static Color tone(AppColors colors, ConnectionStatus status) =>
      switch (status) {
        ConnectionStatus.accepted => colors.success,
        ConnectionStatus.pending => colors.info,
        ConnectionStatus.revoked || ConnectionStatus.expired => colors.warning,
      };

  static String date(BuildContext context, DateTime at) =>
      LocaleNumbers.dateTime(context.locale.languageCode).format(at.toLocal());

  static AppNotification failure(
    BuildContext context,
    ConnectionFailureCode code,
  ) => AppNotification.error(
    title: context.tr('safety.connections.errors.${code.name}.title'),
    message: context.tr('safety.connections.errors.${code.name}.body'),
  );
}
