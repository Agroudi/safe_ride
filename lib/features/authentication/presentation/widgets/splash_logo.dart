import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_logo.dart';
import 'package:safe_ride/core/shared_widgets/brand_seal.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/window_anchor.dart';

/// The splash's [AppLogo] and the launch hand-off, on the splash's
/// `EntranceScope` (`AppDurations.splashIntro`).
///
/// Frame 0 repeats the Android system splash: the launcher icon's flat disc,
/// [AppMotion.launchDisc] dp wide at the window's centre, so the system
/// splash can be removed over it without a seam. The page's scope starts only
/// once it has been (`LaunchHandoff`); the disc then holds still for
/// `AppDurations.splashHold`, rises into its slot and becomes the tile on
/// `AppCurves.seal` while the brand colours warm in and the lane dashes
/// travel one slot and stop. Everything is at rest by `AppMotion.introMorphEnd`, before the seal
/// can fly on to the next screen.
///
/// Under reduced motion, or outside a scope, it is the tile at rest.
class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key, this.size = 96});

  /// Raw design size, passed to [AppLogo].
  final double size;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? intro = EntranceScope.maybeOf(context);
    final int total = EntranceScope.durationOf(context).inMicroseconds;
    if (intro == null || total <= 0 || context.reduceMotion) {
      return BrandSeal(child: AppLogo(size: size));
    }

    double at(Duration offset) => offset.inMicroseconds / total;
    Animation<double> slice(Duration from, Duration to, [Curve? curve]) =>
        intro.drive(
          CurveTween(
            curve: Interval(at(from), at(to), curve: curve ?? Curves.linear),
          ),
        );

    final Animation<double> shape = slice(
      AppMotion.introMorphStart,
      AppMotion.introMorphEnd,
      AppCurves.seal,
    );
    // The Hero sits inside the anchor, around the logo only: a flight starts
    // after the intro, when the anchor is the identity.
    Widget logo = BrandSeal(
      child: AppLogo(
        size: size,
        launch: LogoLaunch(
          shape: shape,
          fill: slice(AppMotion.introMorphStart, AppMotion.introFillEnd),
          glyph: slice(AppMotion.introGlyphStart, AppMotion.introGlyphEnd),
          lanes: slice(
            AppMotion.introMorphStart,
            AppMotion.introMorphEnd,
            AppCurves.drive,
          ),
        ),
      ),
    );
    // iOS has no system disc to hand over from, so the disc fades in over
    // the hold. ⚠️ Not yet verified on an iOS device or simulator.
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      logo = FadeTransition(
        opacity: slice(Duration.zero, AppMotion.introMorphStart),
        alwaysIncludeSemantics: true,
        child: logo,
      );
    }
    return WindowAnchor(
      progress: shape,
      startExtent: AppMotion.launchDisc,
      child: logo,
    );
  }
}
