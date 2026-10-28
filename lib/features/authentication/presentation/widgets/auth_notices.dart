import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';

/// The authentication feature's notifications, translated at the moment
/// they are shown — so login, register and settings word the same event the
/// same way.
///
/// Only what belongs in a notification is here. A wrong password and a
/// taken email are field errors, shown under their inputs, not toasts.
abstract final class AuthNotices {
  /// A failure with no field to show it under. [onCreateAccount] adds the
  /// "Create account" action to `noAccount`.
  static AppNotification failure(
    BuildContext context,
    AuthFailureCode code, {
    VoidCallback? onCreateAccount,
  }) {
    final String key = switch (code) {
      AuthFailureCode.noAccount => 'noAccount',
      AuthFailureCode.storage => 'storage',
      _ => 'unknown',
    };
    final bool offerAccount =
        code == AuthFailureCode.noAccount && onCreateAccount != null;
    return AppNotification.error(
      title: context.tr('auth.errors.$key.title'),
      message: context.tr('auth.errors.$key.message'),
      actionLabel: offerAccount
          ? context.tr('auth.errors.noAccount.action')
          : null,
      onAction: offerAccount ? onCreateAccount : null,
    );
  }

  static AppNotification registered(BuildContext context) =>
      AppNotification.success(
        title: context.tr('auth.notices.registered.title'),
        message: context.tr('auth.notices.registered.message'),
      );

  static AppNotification signedOut(BuildContext context) =>
      AppNotification.info(
        title: context.tr('auth.notices.signedOut.title'),
        message: context.tr('auth.notices.signedOut.message'),
      );

  /// The honest answer to "Forgot your password?" while accounts are local:
  /// nothing pretends to send a reset email.
  static AppNotification resetUnavailable(BuildContext context) =>
      AppNotification(
        kind: AppNotificationKind.info,
        title: context.tr('auth.notices.resetUnavailable.title'),
        message: context.tr('auth.notices.resetUnavailable.message'),
        duration: AppDurations.noticeLong,
      );
}
