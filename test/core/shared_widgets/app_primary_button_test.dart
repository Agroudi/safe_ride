import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Keyboard and D-pad focus must show on the app's main actions. The
/// theme's focus wash is primary, which vanishes on a primary fill.
void main() {
  Future<void> pumpButton(
    WidgetTester tester,
    AppColors colors, {
    bool outlined = false,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(AppDesign.width, AppDesign.height),
        builder: (_, _) => MaterialApp(
          theme: ThemeData(
            focusColor: colors.primary.withValues(alpha: 0.12),
            extensions: <ThemeExtension<dynamic>>[colors],
          ),
          home: Scaffold(
            body: Center(
              child: AppPrimaryButton(
                label: 'Next',
                outlined: outlined,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final (String name, AppColors colors) in <(String, AppColors)>[
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    testWidgets('focus visibly changes the filled button in $name', (
      WidgetTester tester,
    ) async {
      await pumpButton(tester, colors);

      final InkWell ink = tester.widget<InkWell>(find.byType(InkWell));
      final Color focused = Color.alphaBlend(ink.focusColor!, colors.primary);

      expect(focused, isNot(colors.primary));
      expect(_contrast(focused, colors.primary), greaterThan(1.5));
    });

    testWidgets('focus visibly changes the outlined button in $name', (
      WidgetTester tester,
    ) async {
      await pumpButton(tester, colors, outlined: true);

      final InkWell ink = tester.widget<InkWell>(find.byType(InkWell));
      final Color focused = Color.alphaBlend(
        ink.focusColor!,
        colors.background,
      );

      expect(_contrast(focused, colors.background), greaterThan(1.5));
    });
  }
}

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
