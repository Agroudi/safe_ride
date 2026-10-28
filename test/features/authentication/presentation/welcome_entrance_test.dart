import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/presentation/pages/login_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/register_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Fake implements AuthRepository {}

/// The welcome screen's entrance against the real pages and `AppPages`:
/// announced and tappable from its first frame, at rest by 780 ms, and never
/// replayed by a return from a pushed screen — minus `AppTheme` (google_fonts
/// would try to download Cairo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
    // ⚠️ A cached asset Future from an earlier test's fake-async zone never
    // completes in the next one; the translations would never load.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    // Login and register build their own `AuthCubit`; nothing here submits.
    await sl.reset();
    sl.registerFactory<AuthCubit>(() => AuthCubit(_Auth()));
  });
  tearDown(sl.reset);

  /// Pumps up to the first frame that builds [WelcomePage] — its entrance's
  /// t = 0 — with welcome as the first route, or reached by a `go` from a
  /// stand-in splash when [viaGo].
  Future<GoRouter> pumpWelcome(
    WidgetTester tester, {
    bool viaGo = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    GoRoute route(
      String name,
      String path,
      Page<void> Function(BuildContext, GoRouterState) page,
    ) => GoRoute(path: path, name: name, pageBuilder: page);

    final GoRouter router = GoRouter(
      initialLocation: viaGo ? AppRoutes.splashPath : AppRoutes.welcomePath,
      routes: <RouteBase>[
        route(
          AppRoutes.splash,
          AppRoutes.splashPath,
          (BuildContext c, GoRouterState s) =>
              AppPages.stage(c, s, const Scaffold(body: Text('splash'))),
        ),
        route(
          AppRoutes.welcome,
          AppRoutes.welcomePath,
          (BuildContext c, GoRouterState s) =>
              AppPages.stage(c, s, const WelcomePage()),
        ),
        route(
          AppRoutes.login,
          AppRoutes.loginPath,
          (BuildContext c, GoRouterState s) =>
              AppPages.task(c, s, const LoginPage()),
        ),
        route(
          AppRoutes.register,
          AppRoutes.registerPath,
          (BuildContext c, GoRouterState s) =>
              AppPages.task(c, s, const RegisterPage()),
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
    if (viaGo) {
      await tester.pumpAndSettle();
      router.goNamed(AppRoutes.welcome);
    }
    for (
      int i = 0;
      i < 10 && find.byType(WelcomePage).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
    }
    expect(find.byType(WelcomePage), findsOneWidget);
    return router;
  }

  Finder items() => find.descendant(
    of: find.byType(WelcomePage),
    matching: find.byType(EntranceItem),
  );

  /// The opacity [item] is drawn at by its own entrance.
  double opacity(WidgetTester tester, Finder item) => tester
      .widgetList<FadeTransition>(
        find.descendant(of: item, matching: find.byType(FadeTransition)),
      )
      .first
      .opacity
      .value;

  /// True when every entrance item is opaque and nothing moves or scales it.
  bool allAtRest(WidgetTester tester) {
    for (final Element item in items().evaluate()) {
      final Finder one = find.byElementPredicate((Element e) => e == item);
      if (opacity(tester, one) != 1) return false;
      final Transform motion = tester.widget<Transform>(
        find.descendant(of: one, matching: find.byType(Transform)).first,
      );
      if (!motion.transform.isIdentity()) return false;
    }
    return true;
  }

  Animation<double> clock(WidgetTester tester) =>
      EntranceScope.maybeOf(tester.element(items().first))!;

  testWidgets('every control is announced at t = 0, while still invisible', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWelcome(tester);

    // The pill, three rings, title, subtitle and two buttons. The logo is not
    // one: it never enters.
    expect(items(), findsNWidgets(8));
    expect(clock(tester).value, 0);
    for (final String key in <String>[
      'welcome.preferences',
      'welcome.title',
      'welcome.subtitle',
      'welcome.createAccount',
      'welcome.login',
    ]) {
      final Finder text = find.text(key.tr());
      final Finder item = find.ancestor(
        of: text,
        matching: find.byType(EntranceItem),
      );
      expect(opacity(tester, item.first), 0, reason: key);
      expect(find.bySemanticsLabel(key.tr()), findsOneWidget, reason: key);
    }
    expect(find.bySemanticsLabel('app.logoLabel'.tr()), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Create account takes a tap 50 ms into a go arrival', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpWelcome(tester, viaGo: true);

    await tester.pump(const Duration(milliseconds: 50));
    // Still transparent and low, but already live.
    final Finder create = find.text('welcome.createAccount'.tr());
    expect(
      opacity(tester, find.ancestor(of: create, matching: items()).first),
      0,
    );
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(router.state.name, AppRoutes.register);
  });

  testWidgets('at rest by 780 ms, and then nothing ticks', (
    WidgetTester tester,
  ) async {
    await pumpWelcome(tester);
    await tester.pump(const Duration(milliseconds: 770));
    expect(allAtRest(tester), isFalse);

    await tester.pump(const Duration(milliseconds: 10));
    expect(allAtRest(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('coming back from login does not replay the entrance', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpWelcome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('welcome.login'.tr()));
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.login);

    router.pop();
    await tester.pump();
    for (int t = 0; t <= 400; t += 50) {
      expect(clock(tester).value, 1, reason: '$t ms into the pop');
      expect(allAtRest(tester), isTrue, reason: '$t ms into the pop');
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.welcome);
    expect(allAtRest(tester), isTrue);
  });

  testWidgets('covered mid-entrance, it is complete on the way back', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpWelcome(tester);
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.text('welcome.login'.tr()));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();

    expect(clock(tester).value, 1);
    expect(allAtRest(tester), isTrue);
    await tester.pumpAndSettle();
  });
}
