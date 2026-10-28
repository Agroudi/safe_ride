import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';

/// The small accent label of an onboarding step, with a rule on its leading
/// side. The rule is `secondary`; the label is `accentText`, the teal that
/// reads as small text.
///
/// With [enter] the rule draws from its start edge on beat 0 of the page's
/// entrance and the label rises in on beat 1.
class OnboardingEyebrow extends StatelessWidget {
  const OnboardingEyebrow({required this.label, this.enter = false, super.key});

  final String label;
  final bool enter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _Rule(enter: enter),
        Gap(8.fx),
        Flexible(
          child: EntranceItem.beat(
            1,
            rise: AppMotion.riseSmall,
            enabled: enter,
            child: Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.appColors.accentText,
                // ⚠️ Tracking pulls Arabic's joined letters apart; it is for
                // the Latin capitals only.
                letterSpacing: context.isRtl ? 0 : 1.fx,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The rule; with [enter] it grows 0 → 1 from the start edge on beat 0, on
/// `AppCurves.enter`. Paint only.
class _Rule extends StatelessWidget {
  const _Rule({required this.enter});

  final bool enter;

  @override
  Widget build(BuildContext context) {
    final Widget rule = Container(
      width: 22.fx,
      height: 2.fx,
      color: context.appColors.secondary,
    );
    final Animation<double>? scope = EntranceScope.maybeOf(context);
    final int total = EntranceScope.durationOf(context).inMicroseconds;
    if (scope == null || !enter || context.reduceMotion || total <= 0) {
      return rule;
    }

    final Duration at = AppMotion.beat(0);
    final Animation<double> growth = scope.drive(
      CurveTween(
        curve: Interval(
          math.min(at.inMicroseconds / total, 1),
          math.min((at + AppDurations.medium).inMicroseconds / total, 1),
          curve: AppCurves.enter,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: growth,
      builder: (BuildContext context, Widget? child) => Transform(
        alignment: AlignmentDirectional.centerStart,
        transform: Matrix4.diagonal3Values(growth.value, 1, 1),
        child: child,
      ),
      child: rule,
    );
  }
}
