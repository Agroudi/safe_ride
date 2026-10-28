import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/shared_widgets/brand_seal_shape.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

export 'package:safe_ride/core/shared_widgets/brand_seal_shape.dart'
    show BrandSealShape;

/// The SafeRide seal carried from one screen to the next: the **only** Hero
/// in the app, so the mark is never cut while the screen around it changes.
///
/// It flies across `go` as well as `push`, on a straight path (an arc tween
/// made the tile non-square mid-flight) and on `AppCurves.seal`, in the
/// route's own time. In flight it is one shape — the brand gradient, its
/// corners turning from one [BrandSealShape] into the other and, between a
/// tile and a badge, the road mark crossfading into the badge's icon — drawn
/// in the Navigator's overlay and hidden from screen readers, so no second
/// logo is announced.
///
/// Rules: exactly one enabled seal per route, and never state inside
/// [child]. Under reduced motion it never flies.
class BrandSeal extends StatelessWidget {
  const BrandSeal({
    required this.child,
    this.shape = const BrandSealShape.tile(),
    this.enabled = true,
    super.key,
  });

  static const String tag = 'brand-seal';

  final Widget child;
  final BrandSealShape shape;

  /// False: this route's seal neither sends nor receives a flight.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: enabled && !context.reduceMotion,
      child: Hero(
        tag: tag,
        curve: AppCurves.seal,
        createRectTween: (Rect? begin, Rect? end) =>
            RectTween(begin: begin, end: end),
        flightShuttleBuilder: _shuttle,
        child: child,
      ),
    );
  }

  static Widget _shuttle(
    BuildContext flight,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHero,
    BuildContext toHero,
  ) {
    BrandSealShape shapeOf(BuildContext hero) =>
        hero.findAncestorWidgetOfExactType<BrandSeal>()!.shape;
    // A pop runs the animation from 1 to 0: 0 is then where it lands.
    final bool pop = direction == HeroFlightDirection.pop;
    return ExcludeSemantics(
      child: _SealShuttle(
        animation: animation,
        from: shapeOf(pop ? toHero : fromHero),
        to: shapeOf(pop ? fromHero : toHero),
      ),
    );
  }
}

/// The seal in flight: one square shape, never two crossfaded copies (those
/// leave ghost corners). [animation] is the Hero's own, already on
/// `AppCurves.seal`, so the corners turn exactly as the rect moves.
///
/// When the two shapes draw different glyphs, they crossfade inside the one
/// shape over `AppMotion.shuttleCrossfade` of the route's **linear** time
/// (120–280 ms of 400), read from the curve's parent so it is not curved
/// twice.
class _SealShuttle extends AnimatedWidget {
  const _SealShuttle({
    required Animation<double> animation,
    required this.from,
    required this.to,
  }) : super(listenable: animation);

  final BrandSealShape from;
  final BrandSealShape to;

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable as Animation<double>;
    final double t = animation.value;
    final double linear = animation is CurvedAnimation
        ? animation.parent.value
        : t;
    final AppColors colors = context.appColors;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return Center(
          child: Container(
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Physical, as on `AppLogo`: the seal never mirrors.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[colors.primary, colors.secondary],
              ),
              borderRadius: BorderRadius.circular(
                lerpDouble(from.corner, to.corner, t)! * side,
              ),
            ),
            child: BrandSealGlyphs(
              from: from,
              to: to,
              side: side,
              t: t,
              swap: AppMotion.shuttleCrossfade.transform(linear),
            ),
          ),
        );
      },
    );
  }
}
