import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';

/// The authentication feature's notifications, translated at the moment
/// they are shown — so login, register and settings word the same event the
/// same way.
///
/// Only what belongs in a notification is here. Wrong credentials and a
/// taken email are field errors, shown under their inputs, not toasts.
abstract final class AuthNotices {
  /// A failure with no field to show it under. Wrong credentials and a taken
  /// email sit under their inputs instead.
  static AppNotification failure(BuildContext context, AuthFailureCode code) {
    final String key = switch (code) {
      AuthFailureCode.network => 'network',
      AuthFailureCode.tooManyRequests => 'tooManyRequests',
      AuthFailureCode.disabled => 'disabled',
      AuthFailureCode.invalidEmail => 'invalidEmail',
      AuthFailureCode.weakPassword => 'weakPassword',
      AuthFailureCode.storage => 'storage',
      AuthFailureCode.emailTaken ||
      AuthFailureCode.invalidCredentials ||
      AuthFailureCode.unknown => 'unknown',
    };
    return AppNotification.error(
      title: context.tr('auth.errors.title'),
      message: context.tr('auth.errors.$key'),
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
}
