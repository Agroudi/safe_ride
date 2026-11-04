import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_deletion_cubit.dart';
import 'package:safe_ride/features/authentication/presentation/pages/delete_account_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Fake implements AuthRepository {
  AuthFailure? failure;
  final List<String> passwords = <String>[];

  @override
  Future<void> deleteAccount({required String password}) async {
    passwords.add(password);
    final AuthFailure? f = failure;
    if (f != null) throw f;
  }
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late _Auth auth;
  late AppNotifier notices;

  Future<void> show(WidgetTester tester, String language) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    auth = _Auth();
    notices = AppNotifier();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<AccountDeletionCubit>(() => AccountDeletionCubit(auth));
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.deleteAccountPath,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.deleteAccountPath,
          name: AppRoutes.deleteAccount,
          builder: (_, _) => const DeleteAccountPage(),
        ),
        GoRoute(
          path: AppRoutes.welcomePath,
          name: AppRoutes.welcome,
          builder: (_, _) => const Scaffold(body: Text('welcome')),
        ),
      ],
    );
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

  tearDown(sl.reset);

  Finder text(String key) => find.text(key.tr());

  Future<void> submit(WidgetTester tester, {bool confirm = true}) async {
    await tester.enterText(find.byType(TextFormField), 'Secret123');
    await tester.tap(text('profile.delete.submit'));
    await tester.pumpAndSettle();
    await tester.tap(
      text(
        confirm
            ? 'profile.delete.confirm.confirm'
            : 'profile.delete.confirm.cancel',
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says what goes, in Arabic too', (WidgetTester tester) async {
    await show(tester, 'ar');
    expect(find.textContaining('نهائيًا'), findsOneWidget);
    expect(find.textContaining('لا يمكن التراجع'), findsOneWidget);
  });

  testWidgets('needs the password', (WidgetTester tester) async {
    await show(tester, 'en');
    await tester.tap(text('profile.delete.submit'));
    await tester.pumpAndSettle();
    expect(auth.passwords, isEmpty);
    expect(text('profile.delete.confirm.title'), findsNothing);
  });

  testWidgets('asks once more, and No keeps the account', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en');
    await submit(tester, confirm: false);
    expect(auth.passwords, isEmpty);
  });

  testWidgets('done: goes to welcome and says so', (WidgetTester tester) async {
    await show(tester, 'en');
    await submit(tester);
    expect(auth.passwords, <String>['Secret123']);
    expect(find.text('welcome'), findsOneWidget);
    expect(notices.current?.title, 'profile.delete.done'.tr());
    await tester.pump(AppDurations.noticeLong);
  });

  testWidgets('a wrong password shows under the field', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en');
    auth.failure = const AuthFailure(AuthFailureCode.invalidCredentials);
    await submit(tester);
    expect(text('profile.delete.wrongPassword'), findsOneWidget);
    expect(find.byType(DeleteAccountPage), findsOneWidget);
  });

  testWidgets('any other failure says it may be half done', (
    WidgetTester tester,
  ) async {
    await show(tester, 'en');
    auth.failure = const AuthFailure(AuthFailureCode.network);
    await submit(tester);
    expect(notices.current?.title, 'profile.delete.failed.title'.tr());
    expect(find.byType(DeleteAccountPage), findsOneWidget);
    await tester.pump(AppDurations.noticeLong);
  });
}
