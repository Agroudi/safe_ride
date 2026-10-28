import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_logo.dart';
import 'package:safe_ride/core/shared_widgets/brand_seal.dart';
import 'package:safe_ride/core/shared_widgets/brand_seal_shape.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/authentication/presentation/pages/login_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/onboarding_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/splash_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/welcome_page.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_badges.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A session store that answers at once.
class _Auth extends Fake implements AuthRepository {
  _Auth({required this.signedIn});

  final bool signedIn;

  @override
  Future<bool> hasSession() async => signedIn;
}

/// The seal is never cut: the real splash, onboarding, welcome, home and login
/// pages on `AppPages`, the real startup decision, and the one Hero carried across
/// `go` — minus `AppTheme` (google_fonts would try to download Cairo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  tearDown(sl.reset);

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    bool signedIn = false,
    bool onboarded = true,
    String locale = 'en',
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': locale,
      'prefs.onboardingCompleted': onboarded,
    });
    // ⚠️ A cached asset Future from an earlier test's fake-async zone never
    // completes in the next one; the translations would never load.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    final AppPreferences preferences = AppPreferences(
      await SharedPreferences.getInstance(),
    );
    await sl.reset();
    sl
      ..registerFactory<StartupCubit>(
        () => StartupCubit(preferences, _Auth(signedIn: signedIn)),
      )
      ..registerFactory<AuthCubit>(() => AuthCubit(_Auth(signedIn: signedIn)));
    final PreferencesCubit prefs = PreferencesCubit(preferences);
    addTearDown(prefs.close);
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    GoRoute route(String name, String path, Widget page, {bool task = false}) =>
        GoRoute(
          path: path,
          name: name,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              (task ? AppPages.task : AppPages.stage)(context, state, page),
        );
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.splashPath,
      routes: <RouteBase>[
        route(AppRoutes.splash, AppRoutes.splashPath, const SplashPage()),
        route(
          AppRoutes.onboarding,
          AppRoutes.onboardingPath,
          const OnboardingPage(),
        ),
        route(AppRoutes.welcome, AppRoutes.welcomePath, const WelcomePage()),
        // A stand-in: the real home needs the journeys feature, and it
        // carries no seal — all this file needs to know.
        route(
          AppRoutes.home,
          AppRoutes.homePath,
          const Scaffold(body: Text('home')),
        ),
        route(
          AppRoutes.login,
          AppRoutes.loginPath,
          const LoginPage(),
          task: true,
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        child: ScreenUtilInit(
          designSize: const Size(AppDesign.width, AppDesign.height),
          builder: (BuildContext context, _) =>
              BlocProvider<PreferencesCubit>.value(
                value: prefs,
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
    // Up to the splash's first frame.
    for (int i = 0; i < 10 && find.byType(SplashPage).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(find.byType(SplashPage), findsOneWidget);
    return router;
  }

  Finder shuttle() => find.byWidgetPredicate(
    (Widget widget) => widget.runtimeType.toString() == '_SealShuttle',
  );

  /// Pumps [frames] 16 ms frames and returns the shuttle's rect on every
  /// frame it is in flight, checking what must hold on each.
  Future<List<Rect>> watchFlight(WidgetTester tester, {int frames = 50}) async {
    final List<Rect> flight = <Rect>[];
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final int count = shuttle().evaluate().length;
      expect(count, lessThanOrEqualTo(1), reason: 'one shape, never two');
      if (count == 0) continue;

      final Rect rect = tester.getRect(shuttle());
      flight.add(rect);
      expect((rect.width - rect.height).abs(), lessThan(0.5));
      // In the overlay, unheard; both routes' own logos are hidden.
      expect(
        find.ancestor(of: shuttle(), matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(find.byType(AppLogo), findsNothing);
    }
    return flight;
  }

  /// True when [rect] lies strictly between [a] and [b], in size and centre.
  void expectBetween(Rect rect, Rect a, Rect b) {
    bool strictly(double v, double x, double y) =>
        v > (x < y ? x : y) && v < (x < y ? y : x);
    expect(strictly(rect.width, a.width, b.width), isTrue, reason: '$rect');
    expect(
      strictly(rect.center.dy, a.center.dy, b.center.dy),
      isTrue,
      reason: '$rect between $a and $b',
    );
  }

  Rect logoIn<T>(WidgetTester tester) {
    final Finder logo = find.descendant(
      of: find.byType(T),
      matching: find.byType(AppLogo),
    );
    expect(logo, findsOneWidget);
    return tester.getRect(logo);
  }

  for (final String locale in <String>['en', 'ar']) {
    testWidgets('the seal flies from the splash to welcome in $locale', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, locale: locale);
      await tester.pump(const Duration(milliseconds: 590));
      final Rect start = logoIn<SplashPage>(tester);

      final List<Rect> flight = await watchFlight(tester);
      await tester.pumpAndSettle();

      expect(router.state.name, AppRoutes.welcome);
      expect(find.byType(SplashPage), findsNothing);
      final Rect end = logoIn<WelcomePage>(tester);
      expect(flight.length, greaterThan(15));
      expectBetween(flight[flight.length ~/ 2], start, end);
    });
  }

  testWidgets('the shuttle keeps the physical gradient in Arabic', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, locale: 'ar');
    await tester.pump(const Duration(milliseconds: 600));
    for (int i = 0; i < 20 && shuttle().evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(Directionality.of(tester.element(shuttle())), TextDirection.rtl);
    final Container tile = tester.widget<Container>(
      find.descendant(of: shuttle(), matching: find.byType(Container)).first,
    );
    final LinearGradient gradient =
        (tile.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.begin.resolve(TextDirection.rtl), Alignment.topLeft);
    expect(gradient.end.resolve(TextDirection.rtl), Alignment.bottomRight);
    await tester.pumpAndSettle();
  });

  // Home is a journey dashboard with no logo to land on: the splash's seal
  // leaves with its page, and nothing is left flying.
  testWidgets('signed in, nothing flies to home', (WidgetTester tester) async {
    final GoRouter router = await pumpApp(tester, signedIn: true);
    await tester.pump(const Duration(milliseconds: 590));

    expect(await watchFlight(tester), isEmpty);
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.home);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('under reduced motion the seal never flies', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final GoRouter router = await pumpApp(tester);

    final List<Rect> flight = await watchFlight(tester, frames: 10);
    expect(flight, isEmpty);
    expect(router.state.name, AppRoutes.welcome);
    expect(find.byType(SplashPage), findsNothing);
    logoIn<WelcomePage>(tester);
  });

  testWidgets('pushing login, and back, carries no seal', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.welcome);

    router.pushNamed(AppRoutes.login);
    expect(await watchFlight(tester, frames: 30), isEmpty);
    expect(router.state.name, AppRoutes.login);
    router.pop();
    expect(await watchFlight(tester, frames: 30), isEmpty);
    logoIn<WelcomePage>(tester);
  });

  testWidgets('the seal flies from the splash into the step-1 badge', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester, onboarded: false);
    await tester.pump(const Duration(milliseconds: 590));
    final Rect start = logoIn<SplashPage>(tester);

    final List<Rect> flight = <Rect>[];
    final List<double> swaps = <double>[];
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (shuttle().evaluate().isEmpty) continue;
      expect(shuttle(), findsOneWidget, reason: 'one shape, never two');
      final Rect rect = tester.getRect(shuttle());
      flight.add(rect);
      expect((rect.width - rect.height).abs(), lessThan(0.5));
      expect(
        find.ancestor(of: shuttle(), matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(find.byType(AppLogo), findsNothing);
      // One shape: its corners round from the tile's toward the disc's.
      final Container tile = tester.widget<Container>(
        find.descendant(of: shuttle(), matching: find.byType(Container)).first,
      );
      final BorderRadius radius =
          (tile.decoration! as BoxDecoration).borderRadius! as BorderRadius;
      expect(
        radius.topLeft.x / rect.width,
        inInclusiveRange(0.28 - 1e-6, 0.5 + 1e-6),
      );
      // The mark crossfades into the shield on the route's linear time.
      final List<BrandSealGlyph> glyphs = tester
          .widgetList<BrandSealGlyph>(
            find.descendant(
              of: shuttle(),
              matching: find.byType(BrandSealGlyph),
            ),
          )
          .toList();
      expect(glyphs, hasLength(2));
      final BrandSealGlyph shield = glyphs.firstWhere(
        (BrandSealGlyph g) => g.shape.icon != null,
      );
      final BrandSealGlyph mark = glyphs.firstWhere(
        (BrandSealGlyph g) => g.shape.icon == null,
      );
      expect(shield.shape.icon, Icons.shield_rounded);
      expect(mark.opacity + shield.opacity, closeTo(1, 1e-9));
      final double linear = ModalRoute.of(
        tester.element(find.byType(OnboardingPage)),
      )!.animation!.value;
      expect(
        shield.opacity,
        closeTo(AppMotion.shuttleCrossfade.transform(linear), 1e-9),
      );
      swaps.add(shield.opacity);
    }

    expect(router.state.name, AppRoutes.onboarding);
    expect(find.byType(SplashPage), findsNothing);
    expect(flight.length, greaterThan(15));
    final Rect end = tester.getRect(
      find.descendant(
        of: find.byType(OnboardingPage),
        matching: find.byType(OnboardingBadge),
      ),
    );
    expectBetween(flight[flight.length ~/ 2], start, end);
    expect(swaps.first, 0);
    expect(swaps.last, 1);
    for (int i = 1; i < swaps.length; i++) {
      expect(swaps[i], greaterThanOrEqualTo(swaps[i - 1]));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('the badge casts its shadow only once the seal has landed', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);
    await tester.pump(const Duration(milliseconds: 600));
    double glow() {
      final Container disc = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(OnboardingBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      return (disc.decoration! as BoxDecoration).boxShadow!.single.color.a;
    }

    for (int i = 0; i < 40 && shuttle().evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(shuttle(), findsOneWidget);
    for (int i = 0; i < 40 && shuttle().evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Just landed, back on its own route: hardly any glow yet.
    expect(glow(), lessThan(0.35 * 0.25));
    await tester.pumpAndSettle();
    expect(glow(), closeTo(0.35, 1e-3));
  });

  testWidgets('onboarding holds one enabled seal at rest and mid-swipe', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, onboarded: false);
    await tester.pumpAndSettle();
    int enabledSeals() => tester
        .widgetList<BrandSeal>(find.byType(BrandSeal))
        .where((BrandSeal seal) => seal.enabled)
        .length;

    expect(enabledSeals(), 1);
    final PageController pages = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    pages.jumpTo(0.5 * pages.position.viewportDimension);
    await tester.pump();
    expect(enabledSeals(), 1);
    pages.jumpTo(0);
    await tester.pumpAndSettle();
  });

  testWidgets('leaving onboarding carries no seal into welcome', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester, onboarded: false);
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.onboarding);

    await tester.tap(find.text('onboarding.skip'.tr()));
    expect(await watchFlight(tester, frames: 40), isEmpty);
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.welcome);
    logoIn<WelcomePage>(tester);
  });
}
