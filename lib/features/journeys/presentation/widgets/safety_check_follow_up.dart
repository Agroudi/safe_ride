import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/escalation_status.dart';

/// What the user can do once no answer was recorded: say they are okay, find
/// help, or close the note — which leaves it open on the journey screen.
class SafetyCheckFollowUp extends StatelessWidget {
  const SafetyCheckFollowUp({
    required this.journeyId,
    required this.busy,
    required this.onOkay,
    required this.onHelp,
    required this.onClose,
    super.key,
  });

  final String journeyId;

  /// "I'm okay" is being recorded: one tap at a time.
  final bool busy;
  final VoidCallback onOkay;
  final VoidCallback onHelp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      // What became of the alert, as far as is known: on this plan, nobody.
      EscalationStatus(journeyId: journeyId),
      AppPrimaryButton(
        label: context.tr('journeys.safetyCheck.followUp.okay'),
        busy: busy,
        onPressed: onOkay,
      ),
      Gap(12.fx),
      AppPrimaryButton(
        label: context.tr('journeys.safetyCheck.followUp.help'),
        outlined: true,
        onPressed: busy ? null : onHelp,
      ),
      Gap(4.fx),
      TextButton(
        onPressed: busy ? null : onClose,
        child: Text(context.tr('journeys.safetyCheck.noAnswer.close')),
      ),
    ],
  );
}
