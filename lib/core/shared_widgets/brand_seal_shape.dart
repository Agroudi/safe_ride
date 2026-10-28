import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/shared_widgets/brand_mark.dart';

/// The shape a `BrandSeal` has on its own screen, as fractions of its side:
/// the corner radius, the box its glyph is drawn in, and the glyph — the road
/// mark, or an [icon].
@immutable
class BrandSealShape {
  /// `AppLogo`'s rounded tile with the road mark.
  const BrandSealShape.tile()
    : corner = BrandMarkGeometry.tileCorner,
      glyph = BrandMarkGeometry.tileGlyph,
      icon = null;

  /// The onboarding badge: a disc with [icon] in place of the mark.
  const BrandSealShape.badge(IconData this.icon)
    : corner = BrandMarkGeometry.badgeCorner,
      glyph = BrandMarkGeometry.badgeGlyph;

  final double corner;
  final double glyph;

  /// Null for the road mark.
  final IconData? icon;
}

/// The glyph [shape] draws on a seal of [side] logical pixels, in `onPrimary`
/// at [opacity]: the road mark (never its lane travel) or the shape's icon.
class BrandSealGlyph extends StatelessWidget {
  const BrandSealGlyph({
    required this.shape,
    required this.side,
    this.opacity = 1,
    this.glyph,
    super.key,
  });

  final BrandSealShape shape;
  final double side;
  final double opacity;

  /// The glyph box as a fraction of [side]; `shape.glyph` when null.
  final double? glyph;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.appColors.onPrimary;
    final IconData? icon = shape.icon;
    final double extent = (glyph ?? shape.glyph) * side;

    return Opacity(
      opacity: opacity,
      child: icon == null
          ? SizedBox.square(
              dimension: extent,
              child: CustomPaint(painter: BrandMarkPainter(color: ink)),
            )
          : Icon(icon, size: extent, color: ink),
    );
  }
}

/// A seal's glyph on its way from [from] to [to] on a [side]-pixel seal: one
/// mark, its box lerped by [t], when both draw the same glyph; otherwise the
/// two glyphs crossfading inside the one shape, [swap] 0 → 1.
class BrandSealGlyphs extends StatelessWidget {
  const BrandSealGlyphs({
    required this.from,
    required this.to,
    required this.side,
    required this.t,
    required this.swap,
    super.key,
  });

  final BrandSealShape from;
  final BrandSealShape to;
  final double side;
  final double t;
  final double swap;

  @override
  Widget build(BuildContext context) {
    if (from.icon == to.icon) {
      return BrandSealGlyph(
        shape: to,
        side: side,
        glyph: lerpDouble(from.glyph, to.glyph, t),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        BrandSealGlyph(shape: from, side: side, opacity: 1 - swap),
        BrandSealGlyph(shape: to, side: side, opacity: swap),
      ],
    );
  }
}
