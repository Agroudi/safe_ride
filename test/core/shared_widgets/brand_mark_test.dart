import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_assets.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/shared_widgets/app_logo.dart';
import 'package:safe_ride/core/shared_widgets/brand_mark.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mark has three copies — the SVG, the launcher's vector drawable and
/// `BrandMarkGeometry` — and the system splash, the Flutter splash and every
/// logo must be one picture. These fail the day one copy drifts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  const String foreground =
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml';
  const String launcherColors = 'android/app/src/main/res/values/colors.xml';

  test('the launcher icon draws the SVG, path for path', () {
    final List<String> svg = RegExp(r' d="([^"]+)"')
        .allMatches(File(AppAssets.logoMark).readAsStringSync())
        .map((RegExpMatch m) => m[1]!)
        .toList();
    final List<String> xml = RegExp(r'android:pathData="([^"]+)"')
        .allMatches(File(foreground).readAsStringSync())
        .map((RegExpMatch m) => m[1]!)
        .toList();

    expect(svg, hasLength(2));
    expect(xml, svg);
  });

  test('launchTile is the launcher icon background', () {
    final String hex = RegExp(
      r'<color name="ic_launcher_background">#([0-9A-Fa-f]{6})</color>',
    ).firstMatch(File(launcherColors).readAsStringSync())![1]!;
    final Color launcher = Color(int.parse('FF$hex', radix: 16));

    expect(AppColors.light.launchTile, launcher);
    expect(AppColors.dark.launchTile, launcher);
  });

  test('every lane slot is centred on the road; 1–3 are the SVG dashes', () {
    for (final Rect slot in BrandMarkGeometry.laneSlots) {
      expect(slot.center.dx, closeTo(24, 1e-9));
    }
    expect(BrandMarkGeometry.laneSlots.sublist(1, 4), BrandMarkGeometry.dashes);
  });

  group('the lane dashes rest on the SVG pose', () {
    void paintAt(Canvas canvas, double? travel) => BrandMarkPainter(
      color: const Color(0xFFFFFFFF),
      lanes: travel == null ? null : AlwaysStoppedAnimation<double>(travel),
    ).paint(canvas, const Size.square(BrandMarkGeometry.viewBox));

    for (final double? travel in <double?>[null, 0, 1]) {
      test('lanes = $travel draws exactly the three SVG dashes', () {
        final PaintPattern svgPose = paints..path();
        for (final Rect dash in BrandMarkGeometry.dashes) {
          svgPose.rect(rect: dash);
        }

        expect((Canvas c) => paintAt(c, travel), svgPose);
        expect(
          (Canvas c) => paintAt(c, travel),
          paintsExactlyCountTimes(#drawRect, 3),
        );
      });
    }

    test('mid-travel draws four dashes between their slots', () {
      expect(
        (Canvas c) => paintAt(c, 0.5),
        paintsExactlyCountTimes(#drawRect, 4),
      );
      final List<Rect> drawn = <Rect>[];
      expect(
        (Canvas c) => paintAt(c, 0.5),
        paints..everything((Symbol method, List<dynamic> arguments) {
          if (method == #drawRect) drawn.add(arguments.first as Rect);
          return true;
        }),
      );
      const List<Rect> slots = BrandMarkGeometry.laneSlots;
      for (int k = 0; k < 4; k++) {
        expect(
          drawn[k],
          rectMoreOrLessEquals(Rect.lerp(slots[k], slots[k + 1], 0.5)!),
        );
      }
    });
  });

  testWidgets('BrandMarkPainter is the SVG, pixel for pixel', (
    WidgetTester tester,
  ) async {
    const double side = 480; // 10 × the 48-unit box
    tester.view
      ..physicalSize = const Size(side * 2 + 20, side)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const Key svgKey = Key('svg');
    const Key paintKey = Key('painter');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _OnBlack(
              boxKey: svgKey,
              side: side,
              child: SvgPicture.asset(
                AppAssets.logoMark,
                width: side,
                height: side,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 20),
            const _OnBlack(
              boxKey: paintKey,
              side: side,
              child: CustomPaint(
                painter: BrandMarkPainter(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    // flutter_svg parses on a real future: let it finish outside fake time.
    for (int i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    final Uint8List svg = await _pixels(tester, svgKey);
    final Uint8List painted = await _pixels(tester, paintKey);
    int union = 0, both = 0, svgOn = 0;
    for (int i = 0; i < svg.length; i += 4) {
      // Red channel: a white glyph on black.
      final bool a = svg[i] > 127, b = painted[i] > 127;
      if (a) svgOn++;
      if (a || b) union++;
      if (a && b) both++;
    }

    expect(svgOn, greaterThan(1000), reason: 'the SVG actually rendered');
    expect(both / union, greaterThanOrEqualTo(0.999));
  });

  group('the logo is one picture in both reading directions', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
      // ⚠️ A cached asset Future from an earlier test's fake-async zone never
      // completes in the next one; the translations would never load.
      rootBundle.clear();
      await EasyLocalization.ensureInitialized();
    });

    testWidgets('an RTL paint equals an LTR paint', (
      WidgetTester tester,
    ) async {
      const Key ltr = Key('ltr');
      const Key rtl = Key('rtl');
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: AppLocales.supported,
          fallbackLocale: AppLocales.fallback,
          path: AppLocales.translationsPath,
          child: ScreenUtilInit(
            designSize: const Size(AppDesign.width, AppDesign.height),
            builder: (BuildContext context, _) => MaterialApp(
              theme: ThemeData(
                extensions: const <ThemeExtension<dynamic>>[AppColors.light],
              ),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: RepaintBoundary(key: ltr, child: AppLogo()),
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: RepaintBoundary(key: rtl, child: AppLogo()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Uint8List a = await _pixels(tester, ltr);
      final Uint8List b = await _pixels(tester, rtl);

      expect(a.length, greaterThan(0));
      expect(b, a);
    });
  });
}

/// A black square of [side] behind [child], captured by [boxKey].
class _OnBlack extends StatelessWidget {
  const _OnBlack({
    required this.boxKey,
    required this.side,
    required this.child,
  });

  final Key boxKey;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: boxKey,
    child: ColoredBox(
      color: Colors.black,
      child: SizedBox.square(dimension: side, child: child),
    ),
  );
}

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(key));
  return (await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    return bytes!.buffer.asUint8List();
  }))!;
}
