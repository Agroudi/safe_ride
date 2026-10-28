import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';

/// What can still happen to a planned journey: complete it (the user
/// arrived), edit it, or cancel it — each ending asked first. Locked while a
/// change is being saved.
class JourneyActions extends StatelessWidget {
  const JourneyActions({required this.busy, required this.onEdit, super.key});

  final bool busy;
  final VoidCallback onEdit;

  Future<void> _ask(
    BuildContext context,
    String key,
    Future<void> Function() change, {
    bool destructive = false,
  }) async {
    final bool yes = await showAppConfirmDialog(
      context,
      title: context.tr('journeys.$key.title'),
      message: context.tr('journeys.$key.message'),
      confirmLabel: context.tr('journeys.$key.confirm'),
      cancelLabel: context.tr('journeys.$key.cancel'),
      destructive: destructive,
    );
    if (yes) await change();
  }

  @override
  Widget build(BuildContext context) {
    final JourneyCubit journey = context.read<JourneyCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPrimaryButton(
          label: context.tr('journeys.detail.complete'),
          busy: busy,
          onPressed: () => _ask(context, 'confirmComplete', journey.complete),
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('journeys.detail.edit'),
          outlined: true,
          onPressed: busy ? null : onEdit,
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('journeys.detail.cancel'),
          outlined: true,
          color: context.appColors.error,
          onPressed: busy
              ? null
              : () => _ask(
                  context,
                  'confirmCancel',
                  journey.cancel,
                  destructive: true,
                ),
        ),
      ],
    );
  }
}
