import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/brand_mark.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The splash's launch hand-off, each 0..1 from the system-splash disc to the
/// SafeRide tile: [shape] (circle → tile corners, mark box 0.80 → 0.56 of the
/// side), [fill] (flat `launchTile` → the gradient), [glyph] (`onLaunchTile`
/// → `onPrimary`) and [lanes] (`BrandMarkPainter.lanes`).
@immutable
class LogoLaunch {
  const LogoLaunch({
    required this.shape,
    required this.fill,
    required this.glyph,
    required this.lanes,
  });

  final Animation<double> shape, fill, glyph, lanes;
}

/// The SafeRide brand mark: the shield-and-road glyph on a rounded
/// primary → secondary tile.
///
/// Every screen that shows the logo goes through this widget, so a brand change
/// is one file. The glyph is painted by [BrandMarkPainter] — synchronously, on
/// the very first frame, with no asset to load — and tinted `onPrimary`, which
/// stays high-contrast on the tile in both themes. Never mirrored — a logo has
/// no reading direction.
///
/// With a [launch] it starts as the Android system splash draws the launcher
/// icon — a flat `launchTile` disc with the mark in `onLaunchTile` — and
/// becomes the tile as the animations run. Only the splash passes one.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.launch});

  /// Raw design size, converted with `.fx`.
  final double size;

  final LogoLaunch? launch;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final LogoLaunch? launch = this.launch;

    return Semantics(
      label: context.tr('app.logoLabel'),
      image: true,
      child: launch == null
          ? _LogoTile(
              side: size.fx,
              corner: BrandMarkGeometry.tileCorner,
              glyph: BrandMarkGeometry.tileGlyph,
              fill: <Color>[colors.primary, colors.secondary],
              mark: colors.onPrimary,
            )
          : AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                launch.shape,
                launch.fill,
                launch.glyph,
              ]),
              builder: (BuildContext context, _) {
                final double shape = launch.shape.value;
                final double fill = launch.fill.value;
                return _LogoTile(
                  side: size.fx,
                  corner: lerpDouble(
                    BrandMarkGeometry.launchCorner,
                    BrandMarkGeometry.tileCorner,
                    shape,
                  )!,
                  glyph: lerpDouble(
                    BrandMarkGeometry.launchGlyphFraction,
                    BrandMarkGeometry.tileGlyph,
                    shape,
                  )!,
                  // Two equal stops at 0: a flat fill.
                  fill: <Color>[
                    Color.lerp(colors.launchTile, colors.primary, fill)!,
                    Color.lerp(colors.launchTile, colors.secondary, fill)!,
                  ],
                  mark: Color.lerp(
                    colors.onLaunchTile,
                    colors.onPrimary,
                    launch.glyph.value,
                  )!,
                  lanes: launch.lanes,
                );
              },
            ),
    );
  }
}

/// The one tile: [corner] and [glyph] are fractions of [side].
class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.side,
    required this.corner,
    required this.glyph,
    required this.fill,
    required this.mark,
    this.lanes,
  });

  final double side;
  final double corner;
  final double glyph;
  final List<Color> fill;
  final Color mark;
  final Animation<double>? lanes;

  @override
  Widget build(BuildContext context) {
    final Widget painted = CustomPaint(
      painter: BrandMarkPainter(color: mark, lanes: lanes),
    );

    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Physical, not start/end: the one deliberate exception — a brand
        // mark must look the same in Arabic and English.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fill,
        ),
        borderRadius: BorderRadius.circular(corner * side),
      ),
      child: SizedBox.square(
        dimension: glyph * side,
        // The lanes repaint every frame of their travel; keep that off the
        // tile.
        child: lanes == null ? painted : RepaintBoundary(child: painted),
      ),
    );
  }
}
