import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';

/// One piece of a screen's entrance: it fades in and rises (or opens from a
/// scale) on its own slice of the enclosing [EntranceScope].
///
/// Movement runs on `AppCurves.enter` over [length] from [at]; opacity is
/// linear over the first `AppMotion.fadeLead` of it. Paint only — never a
/// relayout — and semantics are present from the first frame, so a screen
/// reader finds the item while it is still transparent. Taps are never
/// blocked.
///
/// Returns [child] untouched outside a scope, when not [enabled], and under
/// reduced motion.
class EntranceItem extends StatelessWidget {
  const EntranceItem({
    required Duration at,
    required this.child,
    this.length = AppDurations.medium,
    this.rise = 0,
    this.scaleFrom = 1,
    this.enabled = true,
    super.key,
  }) : _at = at,
       _beat = 0;

  /// Starts on beat [beat] of the entrance (see `AppMotion.beat`).
  const EntranceItem.beat(
    int beat, {
    required this.child,
    this.length = AppDurations.medium,
    this.rise = 0,
    this.scaleFrom = 1,
    this.enabled = true,
    super.key,
  }) : _at = null,
       _beat = beat;

  final Duration? _at;
  final int _beat;
  final Widget child;

  /// How long the movement takes; the opacity takes the first half of it.
  final Duration length;

  /// Raw design units the item rises from (`.fx` is applied here).
  final double rise;

  /// The scale the item opens from — decorative rings only.
  final double scaleFrom;

  /// False: shown at rest, with no entrance.
  final bool enabled;

  /// When this item starts on the entrance's clock.
  Duration get at => _at ?? AppMotion.beat(_beat);

  @override
  Widget build(BuildContext context) {
    final Animation<double>? scope = EntranceScope.maybeOf(context);
    final int total = EntranceScope.durationOf(context).inMicroseconds;
    if (scope == null || !enabled || context.reduceMotion || total <= 0) {
      return child;
    }

    double fraction(Duration d) =>
        math.min(d.inMicroseconds / total, 1).toDouble();
    final double start = fraction(at);

    return FadeTransition(
      opacity: scope.drive(
        CurveTween(
          curve: Interval(start, fraction(at + length * AppMotion.fadeLead)),
        ),
      ),
      alwaysIncludeSemantics: true,
      child: _EntranceMotion(
        progress: scope.drive(
          CurveTween(
            curve: Interval(
              start,
              fraction(at + length),
              curve: AppCurves.enter,
            ),
          ),
        ),
        rise: rise.fx,
        scaleFrom: scaleFrom,
        child: child,
      ),
    );
  }
}

/// Rises [rise] logical pixels and opens from [scaleFrom] as [progress] goes
/// 0 → 1; the identity at 1.
class _EntranceMotion extends AnimatedWidget {
  const _EntranceMotion({
    required Animation<double> progress,
    required this.rise,
    required this.scaleFrom,
    required this.child,
  }) : super(listenable: progress);

  final double rise;
  final double scaleFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double v = (listenable as Animation<double>).value;
    final double scale = lerpDouble(scaleFrom, 1, v)!;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.translationValues(0, rise * (1 - v), 0)
        ..scaleByDouble(scale, scale, 1, 1),
      child: child,
    );
  }
}
