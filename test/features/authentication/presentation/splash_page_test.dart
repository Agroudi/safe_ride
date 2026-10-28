import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/authentication/presentation/pages/splash_page.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A session store that fails at once, every time — a keystore that throws.
class _BrokenAuthRepository extends Fake implements AuthRepository {
  int calls = 0;

  @override
  Future<bool> hasSession() async {
    calls++;
    throw PlatformException(code: 'keystore');
  }
}

/// The splash with the real [StartupCubit] from the locator, over a session
/// store that always fails — minus `AppTheme` (google_fonts would try to
/// download Cairo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  late _BrokenAuthRepository auth;

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
    auth = _BrokenAuthRepository();
    await sl.reset();
    sl.registerFactory<StartupCubit>(() => StartupCubit(preferences, auth));
  });

  tearDown(sl.reset);

  Future<void> pumpSplash(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.splashPath,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.splashPath,
          name: AppRoutes.splash,
          builder: (_, _) => const SplashPage(),
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
    await tester.pumpAndSettle();
  }

  // A failure that comes back within a frame used to change nothing: same
  // element, same live region, no spinner — the button looked dead and a
  // screen reader said nothing.
  testWidgets('a retry that fails again at once is seen and re-announced', (
    WidgetTester tester,
  ) async {
    await pumpSplash(tester);
    expect(find.byType(SplashFailure), findsOneWidget);
    final Element before = tester.element(find.byType(SplashFailure));

    await tester.tap(find.text('splash.retry'.tr()));
    await tester.pump(const Duration(milliseconds: 16));

    // The attempt is visible: the spinner holds the slot for a moment.
    expect(find.byType(SplashFailure), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(AppDurations.startupRetryMinimum);
    await tester.pumpAndSettle();

    // …and the failure is a new live region, announced again.
    expect(auth.calls, 2);
    expect(find.byType(SplashFailure), findsOneWidget);
    expect(
      identical(tester.element(find.byType(SplashFailure)), before),
      isFalse,
    );
  });
}
