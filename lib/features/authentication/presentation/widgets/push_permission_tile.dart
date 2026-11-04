import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/push/push_notifications.dart';
import 'package:safe_ride/core/push/push_permission_cubit.dart';
import 'package:safe_ride/core/shared_widgets/link_tile.dart';

/// Profile's notifications row: says whether this phone lets SafeRide show
/// notifications, and asks — the only place the app asks, and only on a tap.
/// Once refused, only the phone's settings can change it, and the row says
/// so instead of asking again.
class PushPermissionTile extends StatelessWidget {
  const PushPermissionTile({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<PushPermissionCubit>(
    create: (_) => sl<PushPermissionCubit>()..load(),
    child: BlocBuilder<PushPermissionCubit, PushPermission?>(
      builder: (BuildContext context, PushPermission? permission) => LinkTile(
        icon: permission == PushPermission.allowed
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        title: context.tr('profile.notifications.title'),
        body: context.tr(
          'profile.notifications.${(permission ?? PushPermission.notAsked).name}',
        ),
        onTap: () => switch (permission) {
          PushPermission.notAsked =>
            context.read<PushPermissionCubit>().request(),
          PushPermission.blocked => sl<AppNotifier>().show(
            AppNotification.info(
              title: context.tr('profile.notifications.title'),
              message: context.tr('profile.notifications.howToAllow'),
            ),
          ),
          PushPermission.allowed || null => null,
        },
      ),
    ),
  );
}
