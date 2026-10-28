import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_badges.dart';

/// An accent chip riding the outer ring at [spotDegrees], measured in the
/// reading direction's frame (0° = the end side, y down): −135° is top-start,
/// 45° bottom-end.
///
/// When [enter] is true it fades in on [beat] of the page's entrance and
/// slides the last `AppMotion.orbitSettle` degrees along its ring into place —
/// clockwise in English, counter-clockwise in Arabic. Paint only; at rest, on
/// other steps and under reduced motion it simply sits at its spot.
class OrbitAccent extends StatelessWidget {
  const OrbitAccent({
    required this.icon,
    required this.color,
    required this.spotDegrees,
    required this.beat,
    required this.enter,
    super.key,
  });

  /// The outer ring's radius, raw: the chips' centres lie on it.
  static const double radius = 118;

  final IconData icon;
  final Color color;
  final double spotDegrees;
  final int beat;
  final bool enter;

  @override
  Widget build(BuildContext context) {
    final double spot = spotDegrees * math.pi / 180;
    // How far `Align` can move the chip's centre inside the ring's square.
    const double travel = radius - OnboardingAccent.size / 2;
    final Animation<double>? scope = EntranceScope.maybeOf(context);
    final int total = EntranceScope.durationOf(context).inMicroseconds;
    final Widget chip = OnboardingAccent(icon: icon, color: color);
    double fraction(Duration d) =>
        math.min(d.inMicroseconds / total, 1).toDouble();

    return Align(
      alignment: AlignmentDirectional(
        radius * math.cos(spot) / travel,
        radius * math.sin(spot) / travel,
      ),
      child: scope == null || !enter || context.reduceMotion || total <= 0
          ? chip
          : EntranceItem.beat(
              beat,
              child: _Settle(
                progress: scope.drive(
                  CurveTween(
                    curve: Interval(
                      fraction(AppMotion.beat(beat)),
                      fraction(AppMotion.beat(beat) + AppDurations.medium),
                      curve: AppCurves.enter,
                    ),
                  ),
                ),
                spot: spot,
                radius: radius.fx,
                sign: context.directionSign,
                child: chip,
              ),
            ),
    );
  }
}

/// Moves [child] from `orbitSettle` degrees before [spot] to [spot] along a
/// circle of [radius] as [progress] runs 0 → 1; the identity at 1.
class _Settle extends AnimatedWidget {
  const _Settle({
    required Animation<double> progress,
    required this.spot,
    required this.radius,
    required this.sign,
    required this.child,
  }) : super(listenable: progress);

  final double spot;
  final double radius;
  final double sign;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double e = (listenable as Animation<double>).value;
    final double angle = spot - AppMotion.orbitSettle * math.pi / 180 * (1 - e);
    return Transform.translate(
      offset: Offset(
        sign * radius * (math.cos(angle) - math.cos(spot)),
        radius * (math.sin(angle) - math.sin(spot)),
      ),
      child: child,
    );
  }
}
