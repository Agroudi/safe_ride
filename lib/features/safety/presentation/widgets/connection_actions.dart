import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_links.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_labels.dart';
import 'package:share_plus/share_plus.dart';

/// What the connection screens do on a tap: ask where it matters, act, and say
/// how it went. Each needs a `ConnectionsCubit` above [context].
abstract final class ConnectionActions {
  static void _say(AppNotification notice) => sl<AppNotifier>().show(notice);

  /// Tells the user, and answers whether it went through.
  static bool _reported(BuildContext context, ConnectionFailureCode? failure) {
    if (failure == null) return true;
    if (context.mounted) _say(ConnectionLabels.failure(context, failure));
    return false;
  }

  static Future<void> invite(BuildContext context) async {
    final ConnectionFailureCode? failure = await context
        .read<ConnectionsCubit>()
        .invite();
    if (!context.mounted || !_reported(context, failure)) return;
    _say(
      AppNotification.success(
        title: context.tr('safety.connections.invites.created.title'),
        message: context.tr('safety.connections.invites.created.body'),
      ),
    );
  }

  static Future<void> copy(
    BuildContext context,
    ConnectionInviteModel invite,
  ) async {
    final String copied = context.tr('safety.connections.invites.copied');
    await Clipboard.setData(
      ClipboardData(text: ConnectionLinks.link(invite.token)),
    );
    _say(AppNotification.success(title: copied));
  }

  static Future<void> share(
    BuildContext context,
    ConnectionInviteModel invite,
  ) async {
    final String message = context.tr(
      'safety.connections.invites.message',
      namedArgs: <String, String>{
        'name': invite.inviterName,
        'link': ConnectionLinks.link(invite.token),
      },
    );
    await SharePlus.instance.share(ShareParams(text: message));
  }

  /// A waiting invite is a live key, so taking it back is asked and confirmed;
  /// an expired one is only tidied away.
  static Future<void> cancel(
    BuildContext context,
    ConnectionInviteModel invite, {
    required bool waiting,
  }) async {
    final ConnectionsCubit cubit = context.read<ConnectionsCubit>();
    if (waiting) {
      final bool sure = await showAppConfirmDialog(
        context,
        title: context.tr('safety.connections.invites.cancelConfirm.title'),
        message: context.tr('safety.connections.invites.cancelConfirm.body'),
        confirmLabel: context.tr(
          'safety.connections.invites.cancelConfirm.confirm',
        ),
        cancelLabel: context.tr(
          'safety.connections.invites.cancelConfirm.keep',
        ),
        destructive: true,
      );
      if (!sure) return;
    }
    final ConnectionFailureCode? failure = await cubit.cancel(invite.token);
    if (!context.mounted || !_reported(context, failure) || !waiting) return;
    _say(
      AppNotification.info(
        title: context.tr('safety.connections.invites.cancelled'),
      ),
    );
  }

  /// Answers whether the connection ended.
  static Future<bool> remove(
    BuildContext context,
    ConnectionModel connection,
  ) async {
    final ConnectionsCubit cubit = context.read<ConnectionsCubit>();
    final Map<String, String> name = <String, String>{
      'name': connection.displayName,
    };
    final bool sure = await showAppConfirmDialog(
      context,
      title: context.tr(
        'safety.connections.removeConfirm.title',
        namedArgs: name,
      ),
      message: context.tr('safety.connections.removeConfirm.body'),
      confirmLabel: context.tr('safety.connections.removeConfirm.confirm'),
      cancelLabel: context.tr('safety.connections.removeConfirm.keep'),
      destructive: true,
    );
    if (!sure) return false;
    final ConnectionFailureCode? failure = await cubit.revoke(
      connection.contactUid,
    );
    if (!context.mounted || !_reported(context, failure)) return false;
    _say(
      AppNotification.info(
        title: context.tr('safety.connections.removed.title', namedArgs: name),
        message: context.tr('safety.connections.removed.body'),
      ),
    );
    return true;
  }

  static Future<void> clear(
    BuildContext context,
    ConnectionModel connection,
  ) async {
    final ConnectionFailureCode? failure = await context
        .read<ConnectionsCubit>()
        .clear(connection.contactUid);
    if (context.mounted) _reported(context, failure);
  }
}
