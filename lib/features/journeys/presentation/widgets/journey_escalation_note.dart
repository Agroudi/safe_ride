import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/logic/cubit/open_escalation_cubit.dart';

/// A safety check on this journey that nobody answered, while it stays open:
/// when, that nobody was contacted, "I'm okay", and where to find help.
/// Nothing at all otherwise.
class JourneyEscalationNote extends StatelessWidget {
  const JourneyEscalationNote({required this.journeyId, super.key});

  final String journeyId;

  @override
  Widget build(BuildContext context) => BlocProvider<OpenEscalationCubit>(
    create: (_) => sl<OpenEscalationCubit>()..watch(journeyId),
    child: BlocBuilder<OpenEscalationCubit, OpenEscalation?>(
      builder: (BuildContext context, OpenEscalation? open) =>
          open == null ? const SizedBox.shrink() : _Note(open: open),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.open});

  final OpenEscalation open;

  Future<void> _okay(BuildContext context) async {
    final String thanks = context.tr('journeys.safetyCheck.thanks');
    final ResolveOutcome? outcome = await context
        .read<OpenEscalationCubit>()
        .resolve();
    if (outcome == ResolveOutcome.resolved) {
      sl<AppNotifier>().show(AppNotification.success(title: thanks));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String at = LocaleNumbers.dateTime(
      context.locale.languageCode,
    ).format(open.timedOutAt.toLocal());

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 20.fx),
      child: Container(
        padding: EdgeInsets.all(16.fx),
        decoration: BoxDecoration(
          color: colors.tint(colors.warning),
          borderRadius: BorderRadius.circular(18.fx),
          border: Border.all(color: colors.warning),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              container: true,
              child: Text(
                context.tr(
                  'journeys.escalationNote.title',
                  namedArgs: <String, String>{'time': at},
                ),
                style: context.texts.titleSmall?.copyWith(color: colors.text),
              ),
            ),
            Gap(6.fx),
            Text(
              context.tr('journeys.escalationNote.body'),
              style: context.texts.bodySmall?.copyWith(
                color: colors.text,
                height: 1.5,
              ),
            ),
            Gap(14.fx),
            AppPrimaryButton(
              label: context.tr('journeys.safetyCheck.followUp.okay'),
              onPressed: () => _okay(context),
            ),
            Gap(10.fx),
            AppPrimaryButton(
              label: context.tr('journeys.safetyCheck.followUp.help'),
              outlined: true,
              onPressed: () => context.pushNamed(AppRoutes.safetyHelp),
            ),
          ],
        ),
      ),
    );
  }
}
