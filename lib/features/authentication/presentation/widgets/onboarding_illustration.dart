import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_scene.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/page_parallax.dart';

/// A step's scene: its glyph on a gradient badge, ringed by soft orbits, with
/// the accent icons riding the outer one.
///
/// Built from icons and theme roles rather than a bitmap, so it recolours with
/// the theme and its accents mirror with the reading direction (the badge's
/// light does not: it is the seal's). Purely decorative — the slide's copy
/// says everything it shows — so screen readers skip it.
///
/// The panel moves with its page; the scene inside it lags by
/// `AppMotion.sceneLag` per page, inside the panel's clip. With [enter] the
/// rings open inner to outer on beats 0–2 of the page's entrance and the
/// accents settle along their ring on beats 3 and 4. With [seal] the badge
/// is where the splash's seal lands, and casts its shadow once it has.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    required this.icon,
    required this.pages,
    required this.index,
    super.key,
    this.accents = const <IconData>[],
    this.enter = false,
    this.seal = false,
  });

  final IconData icon;

  /// Up to three small icons around the badge; extras are not drawn.
  final List<IconData> accents;

  /// The onboarding pages, and which one this scene is on.
  final PageController pages;
  final int index;

  /// True on the step the screen opens on: the scene plays its entrance.
  final bool enter;

  /// True: the badge is this route's `BrandSeal`.
  final bool seal;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return ExcludeSemantics(
      child: Container(
        height: 260.fx,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.tint(colors.secondary),
          borderRadius: BorderRadius.circular(32.fx),
        ),
        child: PageParallax(
          pages: pages,
          index: index,
          lag: AppMotion.sceneLag,
          // A swipe re-composites one cached picture of the scene.
          child: RepaintBoundary(
            child: OnboardingScene(
              icon: icon,
              accents: accents,
              enter: enter,
              seal: seal,
            ),
          ),
        ),
      ),
    );
  }
}
