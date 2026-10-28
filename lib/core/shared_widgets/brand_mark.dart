import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_motion.dart';

/// The SafeRide mark as geometry: `assets/images/logo_mark.svg` transcribed by
/// hand, command for command, in its own 48-unit box, plus the proportions
/// every place that draws the mark shares.
///
/// ⚠️ The mark has **three copies**: the SVG (the source of truth),
/// `android/app/src/main/res/drawable/ic_launcher_foreground.xml` and this
/// [body] / [dashes] pair. Change all three together; `brand_mark_test` fails
/// when they drift.
abstract final class BrandMarkGeometry {
  /// The side of the box the paths below are written in.
  static const double viewBox = 48;

  /// SVG path 1 (`fill-rule="evenodd"`): the shield with the road trapezoid
  /// cut out of it.
  static final Path body = Path()
    ..fillType = PathFillType.evenOdd
    // M24 3 L40.5 9.2 C41.4 9.5 42 10.4 42 11.4
    ..moveTo(24, 3)
    ..lineTo(40.5, 9.2)
    ..cubicTo(41.4, 9.5, 42, 10.4, 42, 11.4)
    // V22.6
    ..lineTo(42, 22.6)
    // C42 33.2 34.6 41.9 24.7 44.8
    ..cubicTo(42, 33.2, 34.6, 41.9, 24.7, 44.8)
    // C24.2 44.95 23.8 44.95 23.3 44.8
    ..cubicTo(24.2, 44.95, 23.8, 44.95, 23.3, 44.8)
    // C13.4 41.9 6 33.2 6 22.6
    ..cubicTo(13.4, 41.9, 6, 33.2, 6, 22.6)
    // V11.4 C6 10.4 6.6 9.5 7.5 9.2 Z
    ..lineTo(6, 11.4)
    ..cubicTo(6, 10.4, 6.6, 9.5, 7.5, 9.2)
    ..close()
    // M18.5 37 L22.4 14 H25.6 L29.5 37 Z
    ..moveTo(18.5, 37)
    ..lineTo(22.4, 14)
    ..lineTo(25.6, 14)
    ..lineTo(29.5, 37)
    ..close();

  /// SVG path 2, the centre-line dashes, horizon first:
  /// `M23.4 18.5 h1.2 v3`, `M23.2 24.5 h1.6 v3.5`, `M23 31 h2 v4`.
  static const List<Rect> dashes = <Rect>[
    Rect.fromLTWH(23.4, 18.5, 1.2, 3),
    Rect.fromLTWH(23.2, 24.5, 1.6, 3.5),
    Rect.fromLTWH(23, 31, 2, 4),
  ];

  /// The road's perspective, one dash slot per step from the horizon
  /// (centre y, width, height — every slot is centred on x 24). Slots 1–3
  /// are [dashes] exactly, so every rest pose is the SVG.
  static const List<Rect> laneSlots = <Rect>[
    // 0 · cy 14, 0.8 × 0: the road's top edge. Extrapolated, invisible.
    Rect.fromLTWH(23.6, 14, 0.8, 0),
    // 1 · cy 20, 1.2 × 3
    Rect.fromLTWH(23.4, 18.5, 1.2, 3),
    // 2 · cy 26.25, 1.6 × 3.5
    Rect.fromLTWH(23.2, 24.5, 1.6, 3.5),
    // 3 · cy 33, 2 × 4
    Rect.fromLTWH(23, 31, 2, 4),
    // 4 · cy 40.25, 2.4 × 4.5: one step past the road's end (y 37), inside
    // the solid shield body, so it is invisible. Extrapolated.
    Rect.fromLTWH(22.8, 38, 2.4, 4.5),
  ];

  /// `AppLogo`'s corner radius and mark box, as fractions of the tile side.
  static const double tileCorner = 0.28;
  static const double tileGlyph = 0.56;

  /// The onboarding badge: a circle, its 48-unit icon in a 104-unit disc.
  static const double badgeCorner = 0.5;
  static const double badgeGlyph = 48 / 104;

  /// The Android 12+ system splash: a circle, the mark's box at 128 of 160 dp.
  static const double launchCorner = 0.5;
  static const double launchGlyphFraction =
      AppMotion.launchGlyph / AppMotion.launchDisc;
}

/// Paints the mark in one [color], scaled to the width it is given.
///
/// [lanes] 0..1 moves the lane dashes one slot toward the viewer: a dash grows
/// out of the horizon and the nearest slides past the road's end into the
/// solid shield, where it disappears. At 0, at 1 and with no [lanes] at all it
/// draws the SVG's three dashes exactly. Never reads `Directionality`: the
/// brand is the same picture in both languages.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({required this.color, this.lanes})
    : super(repaint: lanes);

  final Color color;

  /// The splash's lane travel; null for the mark at rest.
  final Animation<double>? lanes;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    canvas
      ..save()
      ..scale(size.width / BrandMarkGeometry.viewBox)
      ..drawPath(BrandMarkGeometry.body, paint);

    final double travel = lanes?.value ?? 0;
    if (travel <= 0 || travel >= 1) {
      for (final Rect dash in BrandMarkGeometry.dashes) {
        canvas.drawRect(dash, paint);
      }
    } else {
      // No clip needed: the nearest dash slides into the shield's own white
      // and the horizon dash grows out of zero height.
      const List<Rect> slots = BrandMarkGeometry.laneSlots;
      for (int k = 0; k < slots.length - 1; k++) {
        final Rect dash = Rect.fromCenter(
          center: Offset(
            BrandMarkGeometry.viewBox / 2,
            lerpDouble(slots[k].center.dy, slots[k + 1].center.dy, travel)!,
          ),
          width: lerpDouble(slots[k].width, slots[k + 1].width, travel)!,
          height: lerpDouble(slots[k].height, slots[k + 1].height, travel)!,
        );
        if (dash.height > 0) canvas.drawRect(dash, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lanes != lanes;
}
