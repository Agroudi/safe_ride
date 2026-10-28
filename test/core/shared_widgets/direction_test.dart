import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_assets.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/shared_widgets/app_logo.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/directional_svg.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What mirrors with the reading direction and what must not: the back
/// chevron points back in both languages, the brand mark is one picture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
    // ⚠️ A cached asset Future from an earlier test's fake-async zone never
    // completes in the next one; the translations would never load.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpIn(
    WidgetTester tester,
    TextDirection direction,
    Widget child,
  ) async {
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
            home: Directionality(
              textDirection: direction,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// True when [svg] is drawn flipped left-to-right.
  bool mirrored(WidgetTester tester, Finder svg) => tester
      .widgetList<Transform>(
        find.descendant(of: svg, matching: find.byType(Transform)),
      )
      .any((Transform flip) => flip.transform.storage[0] < 0);

  // The premise the widget rests on, read from the file itself: the
  // chevron's vertex is its leftmost point, so the asset is a `<`.
  test('the chevron asset is drawn as "<"', () {
    final String svg = File(AppAssets.chevronLeft).readAsStringSync();
    final String path = RegExp(r' d="([^"]+)"').firstMatch(svg)![1]!;
    final List<double> xs = RegExp(r'[ML]\s*([\d.]+)')
        .allMatches(path)
        .map((RegExpMatch point) => double.parse(point[1]!))
        .toList();

    expect(xs, hasLength(3));
    expect(xs[1], lessThan(xs[0]));
    expect(xs[1], lessThan(xs[2]));
  });

  testWidgets('back points left in English: the "<" as drawn', (
    WidgetTester tester,
  ) async {
    await pumpIn(
      tester,
      TextDirection.ltr,
      const DirectionalSvg(AppAssets.chevronLeft),
    );

    expect(mirrored(tester, find.byType(DirectionalSvg)), isFalse);
  });

  testWidgets('back points right in Arabic: the "<" mirrored', (
    WidgetTester tester,
  ) async {
    await pumpIn(
      tester,
      TextDirection.rtl,
      const DirectionalSvg(AppAssets.chevronLeft),
    );

    expect(mirrored(tester, find.byType(DirectionalSvg)), isTrue);
  });

  for (final TextDirection direction in TextDirection.values) {
    testWidgets('the logo tile is the same picture in ${direction.name}', (
      WidgetTester tester,
    ) async {
      await pumpIn(tester, direction, const AppLogo());

      final Container tile = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(Container),
        ),
      );
      final LinearGradient gradient =
          (tile.decoration! as BoxDecoration).gradient! as LinearGradient;

      expect(gradient.begin.resolve(direction), Alignment.topLeft);
      expect(gradient.end.resolve(direction), Alignment.bottomRight);
    });
  }

  // In an RTL field "+966 50…" is drawn "…50 966+"; a phone or an email is
  // typed left to right, yet sits at the reading start like its label.
  testWidgets('phone and email fields type left to right in Arabic', (
    WidgetTester tester,
  ) async {
    await pumpIn(
      tester,
      TextDirection.rtl,
      const Material(
        child: Column(
          children: <Widget>[
            AppTextField(label: 'phone', keyboardType: TextInputType.phone),
            AppTextField(
              label: 'email',
              keyboardType: TextInputType.emailAddress,
            ),
            AppTextField(label: 'name', keyboardType: TextInputType.name),
          ],
        ),
      ),
    );
    final List<EditableText> fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();

    for (final EditableText latin in fields.take(2)) {
      expect(latin.textDirection, TextDirection.ltr);
      expect(latin.textAlign, TextAlign.right);
    }
    expect(fields[2].textDirection, isNull, reason: 'follows the page');
    // The hint too: it lays out in its own direction.
    final List<TextField> boxes = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(boxes[0].decoration?.hintTextDirection, TextDirection.ltr);
    expect(boxes[1].decoration?.hintTextDirection, TextDirection.ltr);
    expect(boxes[2].decoration?.hintTextDirection, isNull);
    expect(fields[2].textAlign, TextAlign.start);
  });
}
