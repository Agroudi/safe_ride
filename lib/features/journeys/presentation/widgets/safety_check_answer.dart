import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/safety_countdown.dart';

/// The countdown, "I'm safe", and what happens without an answer.
class SafetyCheckAnswer extends StatelessWidget {
  const SafetyCheckAnswer({
    required this.left,
    required this.total,
    required this.confirming,
    required this.onSafe,
    super.key,
  });

  /// Time left (`deadline − now`) and the whole countdown.
  final Duration left;
  final Duration total;
  final bool confirming;
  final VoidCallback onSafe;

  @override
  Widget build(BuildContext context) {
    final int seconds = (left.inMilliseconds / 1000).ceil().clamp(
      0,
      total.inSeconds,
    );
    final String digits = LocaleNumbers.decimal(
      context.locale.languageCode,
    ).format(seconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SafetyCountdown(
            seconds: seconds,
            fraction: left.inMilliseconds / total.inMilliseconds,
            digits: digits,
            label: context.plural(
              'journeys.safetyCheck.left',
              seconds,
              namedArgs: <String, String>{'count': digits},
            ),
          ),
        ),
        Gap(20.fx),
        AppPrimaryButton(
          label: context.tr('journeys.safetyCheck.safe'),
          busy: confirming,
          onPressed: onSafe,
        ),
        Gap(14.fx),
        Text(
          context.tr(
            'journeys.safetyCheck.explain',
            namedArgs: <String, String>{
              'seconds': LocaleNumbers.decimal(
                context.locale.languageCode,
              ).format(total.inSeconds),
            },
          ),
          textAlign: TextAlign.center,
          style: context.texts.bodySmall?.copyWith(
            color: context.appColors.textMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
