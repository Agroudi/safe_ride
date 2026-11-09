import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/logic/cubit/safety_help_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/safety_help_state.dart';

/// The top of the help screen: an unanswered safety check, still open, with
/// "I'm okay" — or, with none, what SafeRide cannot do for the user.
class HelpStatusCard extends StatelessWidget {
  const HelpStatusCard({super.key});

  Future<void> _okay(BuildContext context) async {
    final String thanks = context.tr('safety.help.okayDone');
    final ResolveOutcome? outcome = await context
        .read<SafetyHelpCubit>()
        .resolve();
    if (outcome == ResolveOutcome.resolved) {
      sl<AppNotifier>().show(AppNotification.success(title: thanks));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SafetyHelpCubit, SafetyHelpState>(
    builder: (BuildContext context, SafetyHelpState state) {
      final OpenEscalation? open = state.escalation;
      if (open == null) return InfoNote(text: context.tr('safety.help.none'));
      final AppColors colors = context.appColors;
      final String at = LocaleNumbers.dateTime(
        context.locale.languageCode,
      ).format(open.timedOutAt.toLocal());
      return Container(
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
                  'safety.help.open.title',
                  namedArgs: <String, String>{'time': at},
                ),
                style: context.texts.titleSmall?.copyWith(color: colors.text),
              ),
            ),
            Gap(6.fx),
            Text(
              context.tr('safety.help.open.body'),
              style: context.texts.bodySmall?.copyWith(
                color: colors.text,
                height: 1.5,
              ),
            ),
            Gap(14.fx),
            AppPrimaryButton(
              label: context.tr('safety.help.okay'),
              busy: state.resolving,
              onPressed: () => _okay(context),
            ),
          ],
        ),
      );
    },
  );
}
