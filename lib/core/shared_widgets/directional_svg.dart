import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An SVG that points the right way in both reading directions.
///
/// The directional glyphs in `assets/icons` are drawn for **left-to-right**:
/// `chevron_left.svg` is a `<`, "back" in English. Arabic reads the other way,
/// so back must point right (`>`): the asset is shown as drawn in LTR and
/// mirrored in RTL.
///
/// ⚠️ Check an asset's geometry before adding it — not its name or the board
/// it came from. This widget once assumed the chevron was drawn for RTL and
/// mirrored in LTR, so back pointed forward in both languages.
///
/// Only glyphs whose meaning is directional belong in here. A logo, an
/// illustration or a symmetric icon must not be mirrored.
class DirectionalSvg extends StatelessWidget {
  const DirectionalSvg(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    final Widget picture = SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: colorFilter,
    );
    if (Directionality.of(context) == TextDirection.ltr) return picture;
    return Transform.scale(scaleX: -1, child: picture);
  }
}
