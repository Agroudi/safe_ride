import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_logo.dart';
import 'package:safe_ride/core/shared_widgets/brand_mark.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/authentication/presentation/pages/splash_page.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_branding.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_failure.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/window_anchor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A session store that answers when the test says so.
class _PendingAuth extends Fake implements AuthRepository {
  /// Late, so it is made inside the test's fake-async zone: a completer made
  /// in `setUp` completes on the real event loop, which a pumping test never
  /// yields to.
  late final Completer<bool> answer = Completer<bool>();

  @override
  Future<bool> hasSession() => answer.future;
}

/// The splash intro against the real page and startup cubit: frame 0 repeats
/// the system splash, the logo lands in its slot, and the splash leaves at the
/// later of the intro and the decision — minus `AppTheme` (google_fonts would
/// try to download Cairo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  late _PendingAuth auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': 'en',
      'prefs.onboardingCompleted': true,
    });
    // ⚠️ A cached asset Future from an earlier test's fake-async zone never
    // completes in the next one; the translations would never load.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    final AppPreferences preferences = AppPreferences(
      await SharedPreferences.getInstance(),
    );
    auth = _PendingAuth();
    await sl.reset();
    sl.registerFactory<StartupCubit>(() => StartupCubit(preferences, auth));
  });

  tearDown(sl.reset);

  /// Pumps up to the splash's first frame — the intro's t = 0 — on a
  /// 390 × 844 view.
  Future<GoRouter> pumpSplash(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    GoRoute stage(String name, String path, Widget page) => GoRoute(
      path: path,
      name: name,
      pageBuilder: (BuildContext context, GoRouterState state) =>
          AppPages.stage(context, state, page),
    );
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.splashPath,
      routes: <RouteBase>[
        stage(AppRoutes.splash, AppRoutes.splashPath, const SplashPage()),
        stage(
          AppRoutes.welcome,
          AppRoutes.welcomePath,
          const Scaffold(body: Text(AppRoutes.welcome)),
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
          builder: (BuildContext context, _) => MaterialApp.router(
            theme: ThemeData(
              extensions: const <ThemeExtension<dynamic>>[AppColors.light],
            ),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: router,
          ),
        ),
      ),
    );
    for (int i = 0; i < 10 && find.byType(SplashPage).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    expect(find.byType(SplashPage), findsOneWidget);
    return router;
  }

  Rect logo(WidgetTester tester) => tester.getRect(find.byType(AppLogo));

  /// Where the logo was laid out; the anchor never moves its own box.
  Rect slot(WidgetTester tester) => tester.getRect(find.byType(WindowAnchor));

  const Offset viewCentre = Offset(195, 422);

  testWidgets('frame 0 is the system splash: the launch disc, centred', (
    WidgetTester tester,
  ) async {
    auth.answer.complete(false);
    await pumpSplash(tester);

    final Rect disc = logo(tester);
    expect(disc.width, moreOrLessEquals(AppMotion.launchDisc));
    expect(disc.height, moreOrLessEquals(AppMotion.launchDisc));
    expect(disc.center.dx, moreOrLessEquals(viewCentre.dx));
    expect(disc.center.dy, moreOrLessEquals(viewCentre.dy));

    // A flat launcher-tile circle, the mark in its launcher colour at 128 dp.
    final Container tile = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(Container),
      ),
    );
    final BoxDecoration decoration = tile.decoration! as BoxDecoration;
    final double side = tester.getSize(find.byType(AppLogo)).width;
    expect(
      (decoration.borderRadius! as BorderRadius).topLeft.x,
      moreOrLessEquals(side / 2),
    );
    expect((decoration.gradient! as LinearGradient).colors, <Color>[
      AppColors.light.launchTile,
      AppColors.light.launchTile,
    ]);
    final Finder mark = find.descendant(
      of: find.byType(AppLogo),
      matching: find.byWidgetPredicate(
        (Widget w) => w is CustomPaint && w.painter is BrandMarkPainter,
      ),
    );
    final BrandMarkPainter painter =
        tester.widget<CustomPaint>(mark).painter! as BrandMarkPainter;
    expect(painter.color, AppColors.light.onLaunchTile);
    expect(
      tester.getRect(mark).width,
      moreOrLessEquals(AppMotion.launchGlyph, epsilon: 1e-6),
    );

    // The branding waits: transparent, the rules undrawn.
    for (final String key in <String>['splash.title', 'splash.tagline']) {
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(key.tr()),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0, reason: key);
    }
    final Iterable<Transform> rules = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(SplashBranding),
            matching: find.byType(Transform),
          ),
        )
        .where((Transform t) => t.transform.storage[0] == 0);
    expect(rules, hasLength(2));
    await tester.pumpAndSettle();
  });

  testWidgets('holds still, then lands exactly on its slot by 520 ms', (
    WidgetTester tester,
  ) async {
    auth.answer.complete(false);
    await pumpSplash(tester);
    final Rect start = logo(tester);

    await tester.pump(AppMotion.introMorphStart);
    expect(logo(tester), start, reason: 'the hold');

    await tester.pump(const Duration(milliseconds: 200));
    final Rect mid = logo(tester);
    expect(mid.width, lessThan(start.width));
    expect(mid.width, greaterThan(slot(tester).width));

    await tester.pump(const Duration(milliseconds: 200));
    final Rect landed = logo(tester);
    final Rect target = slot(tester);
    expect(landed.left, moreOrLessEquals(target.left, epsilon: 0.01));
    expect(landed.top, moreOrLessEquals(target.top, epsilon: 0.01));
    expect(landed.width, moreOrLessEquals(target.width, epsilon: 0.01));
    expect(target.width, 96);
    await tester.pumpAndSettle();
  });

  testWidgets('decided at once: leaves on the first frame after 600 ms', (
    WidgetTester tester,
  ) async {
    auth.answer.complete(false);
    final GoRouter router = await pumpSplash(tester);

    await tester.pump(const Duration(milliseconds: 599));
    expect(router.state.name, AppRoutes.splash);
    await tester.pump(const Duration(milliseconds: 17));
    expect(router.state.name, AppRoutes.welcome);
    await tester.pumpAndSettle();
  });

  testWidgets('decided at 1000 ms: leaves at 1000 ms', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpSplash(tester);

    // The intro ends on the first frame after 600 ms, and the spinner is
    // built on the next: `onComplete` runs after its frame.
    await tester.pump(const Duration(milliseconds: 608));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 360));
    expect(router.state.name, AppRoutes.splash);

    auth.answer.complete(false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(router.state.name, AppRoutes.welcome);
    await tester.pumpAndSettle();
  });

  testWidgets('a failure at 100 ms is shown only once the intro is over', (
    WidgetTester tester,
  ) async {
    await pumpSplash(tester);
    final Rect brand = tester.getRect(find.byType(SplashBranding));

    await tester.pump(const Duration(milliseconds: 100));
    auth.answer.completeError(PlatformException(code: 'keystore'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 476));
    expect(find.byType(SplashFailure), findsNothing);
    // Nothing moved the brand during the hand-off.
    expect(tester.getRect(find.byType(SplashBranding)), brand);

    // The frame after 600 ms ends the intro; the next one shows the failure.
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(SplashFailure), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(SplashFailure), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(SplashFailure), findsOneWidget);
  });

  testWidgets('at 2x text the hand-off still starts centred and lands', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    auth.answer.complete(false);
    await pumpSplash(tester);

    expect(logo(tester).center.dx, moreOrLessEquals(viewCentre.dx));
    expect(logo(tester).center.dy, moreOrLessEquals(viewCentre.dy));
    await tester.pump(AppMotion.introMorphEnd);
    expect(
      logo(tester).center.dy,
      moreOrLessEquals(slot(tester).center.dy, epsilon: 0.01),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('under reduced motion: at rest on frame 0, gone right after', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    auth.answer.complete(false);
    final GoRouter router = await pumpSplash(tester);

    expect(find.byType(WindowAnchor), findsNothing);
    expect(logo(tester).size, const Size.square(96));
    final Container tile = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(Container),
      ),
    );
    expect(
      ((tile.decoration! as BoxDecoration).gradient! as LinearGradient).colors,
      <Color>[AppColors.light.primary, AppColors.light.secondary],
    );

    await tester.pump();
    expect(router.state.name, AppRoutes.welcome);
    await tester.pump();
    expect(find.byType(SplashPage), findsNothing);
  });
}
