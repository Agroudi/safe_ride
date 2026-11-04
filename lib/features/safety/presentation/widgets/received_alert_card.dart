import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One alert from someone who named this user a trusted contact: what
/// SafeRide noticed, when, what it does not know, and — when their number
/// is known — a way to call them.
class ReceivedAlertCard extends StatelessWidget {
  const ReceivedAlertCard({
    required this.title,
    required this.time,
    required this.body,
    required this.caution,
    this.callLabel,
    this.onCall,
    super.key,
  });

  final String title;
  final String time;
  final String body;
  final String caution;
  final String? callLabel;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? call = callLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.fx),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: context.texts.titleSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Gap(2.fx),
            Text(
              time,
              style: context.texts.labelSmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
            Gap(10.fx),
            Text(
              body,
              style: context.texts.bodyMedium?.copyWith(
                color: colors.text,
                height: 1.6,
              ),
            ),
            Gap(8.fx),
            Text(
              caution,
              style: context.texts.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.6,
              ),
            ),
            if (call != null) ...<Widget>[
              Gap(14.fx),
              AppPrimaryButton(label: call, onPressed: onCall),
            ],
          ],
        ),
      ),
    );
  }
}
