import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/pages/onboarding_page.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_dots.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding against the real cubit, translations and a router holding a
/// stand-in welcome screen — minus `AppTheme` (google_fonts would try to
/// download Cairo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  late PreferencesCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
    // ⚠️ A cached asset Future from an earlier test's fake-async zone never
    // completes in the next one; the translations would never load.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    cubit = PreferencesCubit(
      AppPreferences(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() => cubit.close());

  Future<GoRouter> pumpOnboarding(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
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
          minTextAdapt: true,
          builder: (BuildContext context, _) =>
              BlocProvider<PreferencesCubit>.value(
                value: cubit,
                child: MaterialApp.router(
                  theme: ThemeData(
                    extensions: const <ThemeExtension<dynamic>>[
                      AppColors.light,
                    ],
                  ),
                  darkTheme: ThemeData(
                    brightness: Brightness.dark,
                    extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
                  ),
                  themeMode: themeMode,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  routerConfig: router,
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The translations loaded: a missing file would show the raw key.
    expect(find.text('Next'), findsOneWidget);
    return router;
  }

  Finder action() => find.descendant(
    of: find.byType(OnboardingFooter),
    matching: find.byType(AppPrimaryButton),
  );

  /// The flag as the next launch reads it.
  Future<bool> onboarded() async {
    SharedPreferences.resetStatic();
    return AppPreferences(
      await SharedPreferences.getInstance(),
    ).onboardingCompleted;
  }

  // The label flips to "get started" as soon as the last slide is halfway
  // in; a quick second tap used to finish onboarding from there, for good.
  testWidgets('a second tap while a slide is moving is ignored', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpOnboarding(tester);

    // Step 1: a double tap moves one step, not two.
    await tester.tap(action());
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(action());
    await tester.pumpAndSettle();
    expect(find.text('onboarding.steps.two.title'.tr()), findsOneWidget);

    // Step 2: a double tap lands on step 3 and does not finish.
    await tester.tap(action());
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('onboarding.start'.tr()), findsOneWidget);
    await tester.tap(action());
    await tester.pumpAndSettle();

    expect(router.state.name, AppRoutes.onboarding);
    expect(find.text('onboarding.steps.three.title'.tr()), findsOneWidget);
    expect(await onboarded(), isFalse);

    // On a settled last step, "get started" finishes.
    await tester.tap(action());
    await tester.pumpAndSettle();

    expect(router.state.name, AppRoutes.welcome);
    expect(await onboarded(), isTrue);
  });

  // The dots are the only visible count of the steps: the "not yet" ones
  // must reach the 3:1 non-text minimum on the background.
  for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('inactive dots reach 3:1 in ${mode.name}', (
      WidgetTester tester,
    ) async {
      await pumpOnboarding(tester, themeMode: mode);
      final AppColors colors = mode == ThemeMode.dark
          ? AppColors.dark
          : AppColors.light;

      final List<Color> dots = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(OnboardingDots),
              matching: find.byType(Container),
            ),
          )
          .map((Container dot) => (dot.decoration! as BoxDecoration))
          .map((BoxDecoration box) => box.color!)
          .where((Color color) => color != colors.primary)
          .toList();

      expect(dots, hasLength(2));
      for (final Color dot in dots) {
        final Color drawn = Color.alphaBlend(dot, colors.background);
        expect(_contrast(drawn, colors.background), greaterThanOrEqualTo(3));
      }
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
