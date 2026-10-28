import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_eyebrow.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_illustration.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/page_parallax.dart';

/// One onboarding step: the glyph at the centre of its illustration, the
/// accents around it, and the translation group its copy lives in
/// (`onboarding.steps.<key>.eyebrow / title / body`).
@immutable
class OnboardingStep {
  const OnboardingStep({
    required this.icon,
    required this.accents,
    required this.key,
  });

  final IconData icon;
  final List<IconData> accents;
  final String key;
}

/// The illustration, then the eyebrow, title and body of one step.
///
/// Scrolls on its own, so a small phone or a large text size pushes the copy
/// down instead of overflowing it.
///
/// The copy moves 1:1 with its page and fades as the page leaves (no text
/// parallax). With [enter] — the step the screen opens on — the eyebrow,
/// title and body rise in on beats 1–3 of the page's entrance.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({
    required this.step,
    required this.pages,
    required this.index,
    super.key,
    this.enter = false,
    this.seal = false,
  });

  final OnboardingStep step;

  /// The onboarding pages, and which one this slide is.
  final PageController pages;
  final int index;

  /// True on the step the screen opens on: the slide plays its entrance.
  final bool enter;

  /// True: this slide's badge is the route's seal (the splash's lands on it).
  final bool seal;

  String _copy(BuildContext context, String part) =>
      context.tr('onboarding.steps.${step.key}.$part');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.screenSide,
        vertical: 12.fx,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OnboardingIllustration(
            icon: step.icon,
            accents: step.accents,
            pages: pages,
            index: index,
            enter: enter,
            seal: seal,
          ),
          Gap(28.fx),
          PageParallax(
            pages: pages,
            index: index,
            fade: true,
            child: OnboardingEyebrow(
              label: _copy(context, 'eyebrow'),
              enter: enter,
            ),
          ),
          Gap(12.fx),
          PageParallax(
            pages: pages,
            index: index,
            fade: true,
            child: EntranceItem.beat(
              2,
              rise: AppMotion.rise,
              enabled: enter,
              child: Semantics(
                header: true,
                child: Text(
                  _copy(context, 'title'),
                  style: context.texts.headlineMedium,
                ),
              ),
            ),
          ),
          Gap(14.fx),
          PageParallax(
            pages: pages,
            index: index,
            fade: true,
            child: EntranceItem.beat(
              3,
              rise: AppMotion.rise,
              enabled: enter,
              child: Text(
                _copy(context, 'body'),
                style: context.texts.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                  height: 1.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
