import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/pages/onboarding_page.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_badges.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_dots.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_footer.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_illustration.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_orbit.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_slide.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding's motion against the real page, cubit and translations: the
/// swipe-linked parallax, copy fade and dots as pure functions of the page,
/// the first step's entrance, and the chips settling along their ring — minus
/// `AppTheme` (google_fonts would try to download Cairo). The test view is
/// the 390-wide design frame, so `.fx` is 1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  late PreferencesCubit cubit;

  Future<void> setUpLocale(String locale) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': locale});
    // ⚠️ A cached asset Future from an earlier test's fake-async zone never
    // completes in the next one; the translations would never load.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    cubit = PreferencesCubit(
      AppPreferences(await SharedPreferences.getInstance()),
    );
    addTearDown(cubit.close);
  }

  /// Pumps up to the first frame that builds [OnboardingPage] — its
  /// entrance's t = 0 — and, when [settle], on to rest.
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    String locale = 'en',
    bool settle = true,
  }) async {
    await setUpLocale(locale);
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.onboardingPath,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.onboardingPath,
          name: AppRoutes.onboarding,
          builder: (_, _) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppRoutes.welcomePath,
          name: AppRoutes.welcome,
          builder: (_, _) => const Scaffold(body: Text(AppRoutes.welcome)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        ignorePluralRules: false,
        child: ScreenUtilInit(
          designSize: const Size(AppDesign.width, AppDesign.height),
          builder: (BuildContext context, _) =>
              BlocProvider<PreferencesCubit>.value(
                value: cubit,
                child: MaterialApp.router(
                  theme: ThemeData(
                    extensions: const <ThemeExtension<dynamic>>[
                      AppColors.light,
                    ],
                  ),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  routerConfig: router,
                ),
              ),
        ),
      ),
    );
    for (
      int i = 0;
      i < 10 && find.byType(OnboardingSlide).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
    }
    expect(find.byType(OnboardingSlide), findsOneWidget);
    if (settle) await tester.pumpAndSettle();
  }

  PageController pages(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  Finder slide(int index) => find.byWidgetPredicate(
    (Widget w) => w is OnboardingSlide && w.index == index,
  );

  /// The scene's x inside its panel: the parallax transform's **child**
  /// (a transform's own origin is reported before it is applied).
  double sceneShift(WidgetTester tester, int index) {
    final Finder illustration = find.descendant(
      of: slide(index),
      matching: find.byType(OnboardingIllustration),
    );
    final Finder panel = find
        .descendant(of: illustration, matching: find.byType(Container))
        .first;
    final Finder scene = find
        .descendant(of: illustration, matching: find.byType(RepaintBoundary))
        .first;
    return tester.getTopLeft(scene).dx - tester.getTopLeft(panel).dx;
  }

  /// The opacity the swipe gives slide [index]'s title; 1 with no fade.
  double titleOpacity(WidgetTester tester, int index, String key) {
    final Finder opacity = find.ancestor(
      of: find.text('onboarding.steps.$key.title'.tr()),
      matching: find.byType(Opacity),
    );
    if (opacity.evaluate().isEmpty) return 1;
    return tester.widget<Opacity>(opacity.first).opacity;
  }

  List<double> dotWidths(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(OnboardingDots),
          matching: find.byType(Container),
        ),
      )
      .map((Container dot) => dot.constraints!.maxWidth)
      .toList();

  for (final String locale in <String>['en', 'ar']) {
    final double sign = locale == 'ar' ? -1 : 1;

    testWidgets(
      '$locale: half a page away, the scene lags and the copy fades',
      (WidgetTester tester) async {
        await pumpOnboarding(tester, locale: locale);
        expect(sceneShift(tester, 0), 0);
        expect(titleOpacity(tester, 0, 'one'), 1);

        final PageController controller = pages(tester);
        controller.jumpTo(0.5 * controller.position.viewportDimension);
        await tester.pump();

        expect(controller.page, closeTo(0.5, 1e-9));
        // Slide 0 is half a page ahead: its scene trails its panel by half the
        // lag, toward the side the page is leaving from.
        expect(
          sceneShift(tester, 0),
          closeTo(sign * 0.5 * AppMotion.sceneLag, 0.01),
        );
        expect(
          sceneShift(tester, 1),
          closeTo(-sign * 0.5 * AppMotion.sceneLag, 0.01),
        );
        // 1 − 0.5 / 0.6: both paragraphs are faint, neither competes.
        expect(titleOpacity(tester, 0, 'one'), closeTo(1 / 6, 1e-6));
        expect(titleOpacity(tester, 1, 'two'), closeTo(1 / 6, 1e-6));
        // The pill is shared between the first two dots.
        final List<double> widths = dotWidths(tester);
        expect(widths[0], closeTo(18, 1e-6));
        expect(widths[1], closeTo(18, 1e-6));
        expect(widths[2], closeTo(10, 1e-6));
      },
    );

    testWidgets('$locale: a Next tap and a drag move by the same function', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester, locale: locale);
      final PageController controller = pages(tester);

      void expectOnCurve() {
        final double p = controller.page!;
        expect(p, inExclusiveRange(0.05, 0.95));
        expect(
          sceneShift(tester, 0),
          closeTo(sign * p * AppMotion.sceneLag, 0.01),
        );
        expect(
          titleOpacity(tester, 0, 'one'),
          closeTo((1 - p / AppMotion.copyFadeSpan).clamp(0.0, 1.0), 1e-6),
        );
        expect(dotWidths(tester)[0], closeTo(10 + 16 * (1 - p), 1e-6));
      }

      await tester.tap(
        find.descendant(
          of: find.byType(OnboardingFooter),
          matching: find.byType(AppPrimaryButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expectOnCurve();
      await tester.pumpAndSettle();
      expect(controller.page, 1);

      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      // Forward is a leftward drag in English, a rightward one in Arabic.
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await drag.moveBy(Offset(-sign * 30, 0));
      await tester.pump();
      await drag.moveBy(Offset(-sign * 120, 0));
      await tester.pump();
      expectOnCurve();
      await drag.up();
      await tester.pumpAndSettle();
      expect(controller.page, 0);
    });

    testWidgets('$locale: chip 0 settles along its ring, not across it', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester, locale: locale, settle: false);
      Finder chip() => find
          .descendant(of: slide(0), matching: find.byType(OnboardingAccent))
          .first;
      Offset centre() => tester.getCenter(
        find.descendant(of: slide(0), matching: find.byType(OnboardingBadge)),
      );

      // Beat 3 is 320 ms; 20 ms in, it is still well short of its spot.
      await tester.pump(const Duration(milliseconds: 340));
      final Offset early = tester.getCenter(chip());
      expect((early - centre()).distance, closeTo(OrbitAccent.radius, 0.5));
      // Mid-beat, on the ring.
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        (tester.getCenter(chip()) - centre()).distance,
        closeTo(OrbitAccent.radius, 0.5),
      );

      await tester.pumpAndSettle();
      final Offset rest = tester.getCenter(chip());
      final Offset spot =
          centre() +
          Offset(
            sign * OrbitAccent.radius * math.cos(-0.75 * math.pi),
            OrbitAccent.radius * math.sin(-0.75 * math.pi),
          );
      expect((rest - spot).distance, lessThan(0.01));
      // Top-start, arriving clockwise in English and counter-clockwise in
      // Arabic: from lower down and further toward the start side.
      expect(early.dy - rest.dy, greaterThan(1));
      expect(sign * (early.dx - rest.dx), lessThan(-1));
    });
  }

  testWidgets('under reduced motion nothing follows the page but the dots', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpOnboarding(tester, settle: false);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    final PageController controller = pages(tester);
    controller.jumpTo(0.5 * controller.position.viewportDimension);
    await tester.pump();

    expect(sceneShift(tester, 0), 0);
    expect(sceneShift(tester, 1), 0);
    expect(titleOpacity(tester, 0, 'one'), 1);
    expect(titleOpacity(tester, 1, 'two'), 1);
    // Direct manipulation: the pill still says where the page is.
    expect(dotWidths(tester).first, closeTo(18, 1e-6));
  });

  testWidgets('Next takes a tap 50 ms into the entrance', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(
      find.descendant(
        of: find.byType(OnboardingFooter),
        matching: find.byType(AppPrimaryButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(pages(tester).page, 1);
    expect(find.text('onboarding.steps.two.title'.tr()), findsOneWidget);
  });

  testWidgets('the entrance is at rest by 780 ms, then nothing ticks', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester, settle: false);
    final Finder title = find.text('onboarding.steps.one.title'.tr());
    double fade(Finder of) => tester
        .widget<FadeTransition>(
          find.ancestor(of: of, matching: find.byType(FadeTransition)).first,
        )
        .opacity
        .value;

    expect(fade(title), 0);
    await tester.pump(const Duration(milliseconds: 770));
    // The footer's rise (beat 4, 380 + 400) is still running.
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(fade(title), 1);
    expect(fade(find.byType(OnboardingDots)), 1);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
