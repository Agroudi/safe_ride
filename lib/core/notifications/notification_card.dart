import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/notification_parts.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One notification: a rounded card outlined in its status colour, the
/// status icon, a heading, the message, an optional action and a close
/// button. Every colour is a theme role, so it is right in both themes.
///
/// A live region: TalkBack reads it when it appears — the status word first
/// ("Error"), so the icon's meaning never rests on colour alone.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onDismiss,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onDismiss;

  static Color tone(AppNotificationKind kind, AppColors colors) =>
      switch (kind) {
        AppNotificationKind.success => colors.success,
        AppNotificationKind.error => colors.error,
        AppNotificationKind.warning => colors.warning,
        AppNotificationKind.info => colors.info,
        AppNotificationKind.offline => colors.textMuted,
      };

  static IconData icon(AppNotificationKind kind) => switch (kind) {
    AppNotificationKind.success => Icons.check_circle_rounded,
    AppNotificationKind.error => Icons.error_rounded,
    AppNotificationKind.warning => Icons.warning_rounded,
    AppNotificationKind.info => Icons.info_rounded,
    AppNotificationKind.offline => Icons.wifi_off_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final AppNotification n = notification;
    final Color status = tone(n.kind, colors);
    final String? message = n.message;
    final String? action = n.actionLabel;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: context.isDark ? colors.surfaceElevated : colors.surface,
        elevation: 6,
        shadowColor: colors.text.withValues(alpha: 0.18),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.fx),
          side: BorderSide(color: status, width: 1.5.fx),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(14.fx, 14.fx, 4.fx, 14.fx),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NotificationStatusIcon(
                icon: icon(n.kind),
                color: status,
                label: context.tr('notifications.kinds.${n.kind.name}'),
              ),
              Gap(12.fx),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2.fx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        n.title,
                        style: context.texts.titleSmall?.copyWith(
                          color: colors.text,
                        ),
                      ),
                      if (message != null) ...<Widget>[
                        Gap(4.fx),
                        Text(
                          message,
                          style: context.texts.bodySmall?.copyWith(
                            color: colors.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                      if (action != null)
                        NotificationAction(
                          label: action,
                          onPressed: () {
                            onDismiss();
                            n.onAction?.call();
                          },
                        ),
                    ],
                  ),
                ),
              ),
              NotificationCloseButton(
                label: context.tr('notifications.dismiss'),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
