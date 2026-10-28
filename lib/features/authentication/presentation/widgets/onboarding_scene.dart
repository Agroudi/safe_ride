import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/brand_seal.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/halo_rings.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_badges.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_orbit.dart';

/// The rings, the badge and the accents of `OnboardingIllustration`, laid
/// out in one square so the accents keep their place on the outer ring at any
/// panel width.
///
/// The rings keep breathing and the dotted orbit keeps turning
/// (`HaloRings`). With [enter] the rings also open inner to outer on beats
/// 0–2 of the page's entrance and the accents settle on beats 3 and 4. With [seal] the badge is
/// the route's `BrandSeal`: the splash's seal lands on it, and its glow ramps
/// in over `AppDurations.short` once it has (`AppMotion.sealLanding`).
class OnboardingScene extends StatelessWidget {
  const OnboardingScene({
    required this.icon,
    required this.accents,
    required this.enter,
    required this.seal,
    super.key,
  });

  final IconData icon;
  final List<IconData> accents;
  final bool enter;
  final bool seal;

  /// The outer ring's diameter, raw — also the side of the square.
  static const double _outer = OrbitAccent.radius * 2;

  /// Top-start, bottom-end, top-end, in the reading direction's frame: the
  /// first two follow the badge's light across the panel.
  static const List<double> _spots = <double>[-135, 45, -45];

  /// The badge's glow, ramping in over `short` once the seal has landed.
  Animation<double>? _landing(BuildContext context) {
    final int total = EntranceScope.durationOf(context).inMicroseconds;
    double fraction(Duration d) =>
        math.min(d.inMicroseconds / total, 1).toDouble();
    const Duration landed = AppMotion.sealLanding;
    return total <= 0
        ? null
        : EntranceScope.maybeOf(context)?.drive(
            CurveTween(
              curve: Interval(
                fraction(landed),
                fraction(landed + AppDurations.short),
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    // The panel is already a secondary wash, so the rings are the same hue a
    // little stronger — a neutral `border` line vanishes on it.
    final Color ring = colors.secondary;

    return Center(
      child: SizedBox.square(
        dimension: _outer.fx,
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: <Widget>[
            HaloRings(
              enter: enter,
              rings: <HaloRing>[
                HaloRing(
                  diameter: 136.fx,
                  fill: ring.withValues(alpha: 0.08),
                  stroke: ring.withValues(alpha: 0.3),
                  strokeWidth: 1.5.fx,
                ),
                HaloRing(
                  diameter: 184.fx,
                  stroke: ring.withValues(alpha: 0.2),
                  strokeWidth: 1.5.fx,
                ),
                HaloRing(
                  diameter: _outer.fx,
                  stroke: ring.withValues(alpha: 0.34),
                  strokeWidth: 1.5.fx,
                  dotted: true,
                ),
              ],
            ),
            if (seal)
              BrandSeal(
                shape: BrandSealShape.badge(icon),
                child: OnboardingBadge(icon: icon, shadow: _landing(context)),
              )
            else
              OnboardingBadge(icon: icon),
            for (int i = 0; i < accents.length && i < _spots.length; i++)
              OrbitAccent(
                icon: accents[i],
                color: i.isEven ? colors.secondary : colors.primary,
                spotDegrees: _spots[i],
                beat: 3 + i,
                enter: enter,
              ),
          ],
        ),
      ),
    );
  }
}
