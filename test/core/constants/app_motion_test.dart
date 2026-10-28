import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/shared_widgets/brand_mark.dart';

/// The motion tokens are derived from each other; these pin the sums, so a
/// changed part cannot leave a stale total behind, and pin the curves'
/// character: nothing overshoots, nothing moves late.
void main() {
  test('an entrance is beat 4 plus one item length', () {
    expect(
      AppDurations.entrance,
      AppMotion.arrivalBeat + AppMotion.stagger * 4 + AppDurations.medium,
    );
    expect(AppMotion.beat(0), AppMotion.arrivalBeat);
    expect(AppMotion.beat(4) + AppDurations.medium, AppDurations.entrance);
  });

  test('the splash intro is the hold, the morph and the landing', () {
    expect(
      AppDurations.splashIntro,
      AppDurations.splashHold +
          AppDurations.medium +
          const Duration(milliseconds: 80),
    );
    expect(AppMotion.introMorphStart, AppDurations.splashHold);
    expect(
      AppMotion.introMorphEnd,
      AppMotion.introMorphStart + AppDurations.medium,
    );
    expect(
      AppMotion.introMorphEnd,
      lessThanOrEqualTo(AppDurations.splashIntro),
    );
  });

  test('the outgoing fade is over when the first beat starts', () {
    expect(AppMotion.arrivalBeat, AppDurations.medium * AppMotion.fadeOutEnd);
    // The incoming page starts before the outgoing one is gone.
    expect(AppMotion.fadeInStart, lessThan(AppMotion.fadeOutEnd));
  });

  test('a seal flight lands when a route transition ends', () {
    expect(AppMotion.sealLanding, AppDurations.medium);
  });

  test('the launch disc holds the mark at 80 %', () {
    expect(BrandMarkGeometry.launchGlyphFraction, closeTo(0.8, 1e-9));
  });

  const Map<String, Curve> curves = <String, Curve>{
    'seal': AppCurves.seal,
    'move': AppCurves.move,
    'enter': AppCurves.enter,
    'exit': AppCurves.exit,
    'drive': AppCurves.drive,
  };

  for (final MapEntry<String, Curve> curve in curves.entries) {
    test('${curve.key} is monotonic and never overshoots', () {
      double previous = 0;
      for (int i = 0; i <= 100; i++) {
        final double value = curve.value.transform(i / 100);
        expect(value, inInclusiveRange(0, 1), reason: 't = ${i / 100}');
        expect(value, greaterThanOrEqualTo(previous), reason: 't = ${i / 100}');
        previous = value;
      }
    });
  }

  // The system splash exits over an unmoving image: the first frame of the
  // morph, 16 ms in, must not visibly move.
  test('the morph does not visibly move on its first frame', () {
    expect(AppCurves.seal.transform(16 / 400), lessThan(0.005));
  });

  // A tap answered at once: a Next slide is past halfway by a quarter of
  // its length (80 ms of 400).
  test('a move is more than half done a quarter of the way in', () {
    expect(AppCurves.move.transform(0.25), greaterThan(0.5));
  });
}
