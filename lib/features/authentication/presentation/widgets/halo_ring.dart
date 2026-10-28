import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_motion.dart';

/// One circle of `HaloRings`. Sizes are logical pixels (already `.fx`).
@immutable
class HaloRing {
  const HaloRing({
    required this.diameter,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.dotted = false,
  });

  final double diameter;
  final Color? fill;
  final Color? stroke;

  /// The line's width, or the dots' radius when [dotted].
  final double strokeWidth;

  /// A ring of `AppMotion.haloDots` dots that turns once per
  /// `AppDurations.haloCycle` — the orbit.
  final bool dotted;
}

/// Paints one [HaloRing] at its place in the loop: breath [index] trails the
/// one inside it, and a dotted ring turns with [sign] (the reading
/// direction). Repaints from [clock] alone — never a rebuild.
class HaloRingPainter extends CustomPainter {
  HaloRingPainter({
    required this.ring,
    required this.index,
    required this.clock,
    required this.still,
    required this.sign,
  }) : super(repaint: still ? null : clock);

  final HaloRing ring;
  final int index;
  final Animation<double> clock;
  final bool still;
  final double sign;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = still ? 0 : clock.value;
    // 0 at rest, 1 at the top of the breath; ring n trails ring 0 by
    // n × haloLag breaths, so the wave rolls outward.
    final double phase =
        (t * AppMotion.haloBreaths - index * AppMotion.haloLag) % 1;
    final double breath = still ? 0 : 0.5 - 0.5 * math.cos(2 * math.pi * phase);
    final double radius =
        ring.diameter / 2 * (1 + AppMotion.haloSwell * breath);
    final double glow = 1 + AppMotion.haloGlow * breath;
    final Offset centre = size.center(Offset.zero);

    final Color? fill = ring.fill;
    if (fill != null) {
      canvas.drawCircle(centre, radius, Paint()..color = _stronger(fill, glow));
    }
    final Color? stroke = ring.stroke;
    if (stroke == null) return;
    final Paint ink = Paint()
      ..color = _stronger(stroke, glow)
      ..isAntiAlias = true;
    final double w = ring.strokeWidth;
    if (!ring.dotted) {
      canvas.drawCircle(
        centre,
        radius - w / 2,
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w,
      );
      return;
    }
    final double turn = sign * 2 * math.pi * t;
    for (int k = 0; k < AppMotion.haloDots; k++) {
      final double a = turn + 2 * math.pi * k / AppMotion.haloDots;
      canvas.drawCircle(
        centre + Offset(math.cos(a), math.sin(a)) * (radius - w),
        w,
        ink,
      );
    }
  }

  static Color _stronger(Color c, double k) =>
      c.withValues(alpha: math.min(c.a * k, 1));

  @override
  bool shouldRepaint(HaloRingPainter old) =>
      old.still != still ||
      old.sign != sign ||
      old.index != index ||
      old.ring.diameter != ring.diameter ||
      old.ring.fill != ring.fill ||
      old.ring.stroke != ring.stroke ||
      old.ring.strokeWidth != ring.strokeWidth ||
      old.ring.dotted != ring.dotted;
}
