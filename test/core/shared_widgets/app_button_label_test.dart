import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/shared_widgets/app_button_label.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/press_scale.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The button's label swap and press: one label is announced at a time, and
/// both are instant or inert when the system asks for no animations.
void main() {
  Widget button({
    String label = 'Next',
    bool busy = false,
    VoidCallback? onPressed,
    bool reduceMotion = false,
  }) => ScreenUtilInit(
    designSize: const Size(AppDesign.width, AppDesign.height),
    builder: (_, _) => MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[AppColors.light],
      ),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: AppPrimaryButton(
              label: label,
              busy: busy,
              onPressed: onPressed ?? () {},
            ),
          ),
        ),
      ),
    ),
  );

  group('the label swap', () {
    testWidgets('announces only the new label mid-swap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(button());
      await tester.pumpWidget(button(label: 'Get started'));
      await tester.pump(const Duration(milliseconds: 100));

      // Both are painted…
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      // …one is heard.
      expect(tester.getSemantics(find.byType(InkWell)).label, 'Get started');
      expect(find.bySemanticsLabel('Next'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Next'), findsNothing);
      semantics.dispose();
    });

    testWidgets('swaps in place: the button keeps its size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(button(label: 'Get started'));
      final Size before = tester.getSize(find.byType(AppPrimaryButton));
      await tester.pumpWidget(button(label: 'Next'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.getSize(find.byType(AppPrimaryButton)), before);
      await tester.pumpAndSettle();
    });

    testWidgets('a busy button still announces its label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(button());
      await tester.pumpWidget(button(busy: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('is instant under reduced motion', (WidgetTester tester) async {
      await tester.pumpWidget(button(reduceMotion: true));
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );

      await tester.pumpWidget(button(label: 'Get started', reduceMotion: true));
      await tester.pump();

      expect(find.text('Next'), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('AppButtonLabel never sizes to more than one line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(button(label: 'A label far too long ' * 8));

      final Text text = tester.widget<Text>(
        find.descendant(
          of: find.byType(AppButtonLabel),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('PressScale', () {
    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(PressScale),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    testWidgets('gives under the finger and comes back', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(button(onPressed: () => taps++));

      final TestGesture finger = await tester.startGesture(
        tester.getCenter(find.byType(AppPrimaryButton)),
      );
      await tester.pump();
      await tester.pump(AppDurations.press);
      expect(scale(tester), moreOrLessEquals(AppMotion.pressScale));

      await finger.up();
      await tester.pump();
      await tester.pump(AppDurations.short);
      expect(scale(tester), 1);
      // The tap itself is untouched.
      expect(taps, 1);
    });

    for (final (String name, bool busy, bool reduceMotion)
        in <(String, bool, bool)>[
          ('disabled (busy)', true, false),
          ('under reduced motion', false, true),
        ]) {
      testWidgets('is inert when $name', (WidgetTester tester) async {
        await tester.pumpWidget(button(busy: busy, reduceMotion: reduceMotion));

        final TestGesture finger = await tester.startGesture(
          tester.getCenter(find.byType(AppPrimaryButton)),
        );
        await tester.pump();
        await tester.pump(AppDurations.press);
        expect(scale(tester), 1);

        // A busy spinner never settles; one release frame is enough.
        await finger.up();
        await tester.pump(AppDurations.short);
      });
    }
  });
}
