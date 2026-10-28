import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';

/// The product name and its tagline flanked by two short rules.
///
/// The tagline is [Flexible], so a long translation or a large text scale
/// wraps between the rules instead of overflowing the row.
///
/// On the splash's `EntranceScope` the name rises in, then the tagline, and
/// the rules draw outward from the tagline — all landed by the end of the
/// intro. Outside a scope or under reduced motion it is simply there.
class SplashBranding extends StatelessWidget {
  const SplashBranding({required this.title, required this.tagline, super.key});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? intro = EntranceScope.maybeOf(context);
    final int total = EntranceScope.durationOf(context).inMicroseconds;
    final Animation<double> rules =
        intro == null || total <= 0 || context.reduceMotion
        ? kAlwaysCompleteAnimation
        : intro.drive(
            CurveTween(
              curve: Interval(
                AppMotion.introRulesAt.inMicroseconds / total,
                1,
                curve: AppCurves.enter,
              ),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EntranceItem(
          at: AppMotion.introTitleAt,
          rise: AppMotion.rise,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.texts.headlineMedium,
          ),
        ),
        Gap(8.fx),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Rule(growth: rules, from: AlignmentDirectional.centerEnd),
            Gap(10.fx),
            Flexible(
              child: EntranceItem(
                at: AppMotion.introTaglineAt,
                // Landed by the end of the intro.
                length: AppDurations.splashIntro - AppMotion.introTaglineAt,
                rise: AppMotion.riseSmall,
                child: Text(
                  tagline,
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall,
                ),
              ),
            ),
            Gap(10.fx),
            _Rule(growth: rules, from: AlignmentDirectional.centerStart),
          ],
        ),
      ],
    );
  }
}

/// A short teal rule that draws from [from] — the side facing the tagline —
/// as [growth] goes 0 → 1. Paint only.
class _Rule extends StatelessWidget {
  const _Rule({required this.growth, required this.from});

  final Animation<double> growth;
  final AlignmentDirectional from;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: growth,
      builder: (BuildContext context, Widget? child) => Transform(
        alignment: from,
        transform: Matrix4.diagonal3Values(growth.value, 1, 1),
        child: child,
      ),
      child: Container(
        width: 20.fx,
        height: 2.fx,
        decoration: BoxDecoration(
          color: context.appColors.secondary,
          borderRadius: BorderRadius.circular(2.fx),
        ),
      ),
    );
  }
}
