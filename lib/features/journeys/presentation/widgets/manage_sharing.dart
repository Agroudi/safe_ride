import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/core/shared_widgets/status_chip.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/share_labels.dart';
import 'package:share_plus/share_plus.dart';

/// An active share: that it is on, what it shows, when it ends, whether
/// updates are getting through, and the link.
class ManageSharing extends StatelessWidget {
  const ManageSharing({required this.status, required this.onStop, super.key});

  final ShareStatus status;
  final VoidCallback onStop;

  Future<void> _copy(BuildContext context) async {
    final String copied = context.tr('sharing.manage.copied');
    await Clipboard.setData(ClipboardData(text: status.record.link));
    sl<AppNotifier>().show(AppNotification.success(title: copied));
  }

  Future<void> _share(BuildContext context) async {
    final String message = context.tr(
      'sharing.manage.message',
      namedArgs: <String, String>{'link': status.record.link},
    );
    await SharePlus.instance.share(ShareParams(text: message));
  }

  Future<void> _stop(BuildContext context) async {
    final bool sure = await showAppConfirmDialog(
      context,
      title: context.tr('sharing.manage.stopConfirm.title'),
      message: context.tr('sharing.manage.stopConfirm.body'),
      confirmLabel: context.tr('sharing.manage.stop'),
      cancelLabel: context.tr('sharing.manage.stopConfirm.keep'),
      destructive: true,
    );
    if (sure) onStop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final ShareRecord record = status.record;
    final DateTime? delivered = status.lastDeliveredAt;
    final String kind = record.kind == ShareKind.journey
        ? 'journey'
        : 'location';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusChip(
            label: ShareLabels.delivery(context, status.delivery),
            color: ShareLabels.deliveryTone(colors, status.delivery),
          ),
        ),
        Gap(12.fx),
        Text(
          context.tr('sharing.manage.$kind'),
          style: context.texts.bodyMedium?.copyWith(color: colors.text),
        ),
        Gap(6.fx),
        Text(
          context.tr(
            'sharing.manage.ends',
            namedArgs: <String, String>{
              'time': MapLabels.clock(context, record.expiresAt),
            },
          ),
          style: context.texts.bodyMedium?.copyWith(color: colors.textMuted),
        ),
        if (delivered != null) ...<Widget>[
          Gap(2.fx),
          Text(
            context.tr(
              'sharing.manage.lastUpdate',
              namedArgs: <String, String>{
                'time': MapLabels.clock(context, delivered),
              },
            ),
            style: context.texts.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        ],
        Gap(20.fx),
        AppPrimaryButton(
          label: context.tr('sharing.manage.share'),
          onPressed: () => _share(context),
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('sharing.manage.copy'),
          outlined: true,
          onPressed: () => _copy(context),
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('sharing.manage.stop'),
          outlined: true,
          color: colors.error,
          onPressed: () => _stop(context),
        ),
        Gap(20.fx),
        InfoNote(text: context.tr('sharing.manage.privacy')),
        Gap(8.fx),
        InfoNote(text: context.tr('sharing.notEmergency')),
      ],
    );
  }
}
