import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The step indicator: one bar per step, the active one a wide pill that
/// stretches with the finger — each bar's weight is
/// `clamp(1 − |page − i|, 0, 1)` of [pages], so the pill moves exactly as the
/// slides do and never on a clock of its own.
///
/// [index] stands in for the page until [pages] has laid out. The row reads as
/// nothing to a screen reader; the footer says "step n of m" instead.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    required this.pages,
    required this.count,
    required this.index,
    super.key,
  });

  final PageController pages;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // A faded muted tone reads as "not yet", but must stay at 3:1 on the
    // background to be counted: 0.8 gives 3.1:1 in light, 0.6 gives 3.9:1 in
    // dark. The active step is also told apart by its width.
    final Color inactive = colors.textMuted.withValues(
      alpha: context.isDark ? 0.6 : 0.8,
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pages,
        builder: (BuildContext context, _) {
          final bool ready = pages.hasClients && pages.position.haveDimensions;
          final double page = ready ? pages.page! : index.toDouble();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < count; i++) ...<Widget>[
                if (i > 0) Gap(6.fx),
                _Dot(
                  weight: (1 - (page - i).abs()).clamp(0.0, 1.0),
                  inactive: inactive,
                  active: colors.primary,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One bar, [weight] 0 (a "not yet" dot) to 1 (the active pill).
class _Dot extends StatelessWidget {
  const _Dot({
    required this.weight,
    required this.inactive,
    required this.active,
  });

  final double weight;
  final Color inactive;
  final Color active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (10 + 16 * weight).fx,
      height: 5.fx,
      decoration: BoxDecoration(
        // Exact at rest: the lerp only runs between two steps.
        color: weight == 0
            ? inactive
            : weight == 1
            ? active
            : Color.lerp(inactive, active, weight),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
