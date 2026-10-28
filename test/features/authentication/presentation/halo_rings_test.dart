import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/halo_rings.dart';

/// The rings never stop moving — unless the system asks for no animations or
/// the screen is covered — and they repaint without rebuilding.
void main() {
  setUp(() => HaloRings.ambient = true);
  tearDown(() => HaloRings.ambient = false);

  Widget rings({bool reduceMotion = false, bool ticking = true}) {
    return ScreenUtilInit(
      designSize: const Size(AppDesign.width, AppDesign.height),
      builder: (_, _) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: ticking,
            child: const Center(
              child: HaloRings(
                enter: false,
                rings: <HaloRing>[
                  HaloRing(diameter: 120, fill: Color(0xFF00FF00)),
                  HaloRing(
                    diameter: 208,
                    stroke: Color(0x8800FF00),
                    dotted: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps animating long after any entrance', (tester) async {
    await tester.pumpWidget(rings());
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 7));
      expect(tester.binding.hasScheduledFrame, isTrue);
    }
  });

  testWidgets('paints on its own layer, so a frame repaints only the rings', (
    tester,
  ) async {
    await tester.pumpWidget(rings());
    expect(
      find.descendant(
        of: find.byType(HaloRings),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('rests under reduced motion', (tester) async {
    await tester.pumpWidget(rings(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('pauses while its ticker is muted (covered, backgrounded)', (
    tester,
  ) async {
    await tester.pumpWidget(rings(ticking: false));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(rings());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
