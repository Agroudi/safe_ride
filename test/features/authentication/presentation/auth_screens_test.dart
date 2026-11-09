import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_asset_loader.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/country/country_cubit.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/push/push_notifications.dart';
import 'package:safe_ride/core/push/push_permission_cubit.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/password_reset_cubit.dart';
import 'package:safe_ride/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/login_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/register_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/about_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/edit_profile_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/profile_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/country/country_fakes.dart';

final UserModel _sara = UserModel(
  fullName: 'Sara Ahmed',
  email: 'sara@example.com',
  phone: '+966 50 123 4567',
  createdAt: DateTime.utc(2026),
);

/// Fails with [failure] when set, waits on [pending] when set, and counts.
class _Repository extends Fake implements AuthRepository {
  AuthFailure? failure;
  Completer<UserModel>? pending;
  int submits = 0;
  int logouts = 0;
  int updates = 0;
  UserModel user = _sara;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  Future<UserModel> _answer() async {
    submits++;
    final Completer<UserModel>? wait = pending;
    if (wait != null) return wait.future;
    final AuthFailure? f = failure;
    if (f != null) throw f;
    return _sara;
  }

  @override
  Future<UserModel> login({required String email, required String password}) =>
      _answer();

  @override
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    required String languageCode,
    String? phone,
  }) => _answer();

  @override
  Future<UserModel?> currentUser() async => user;

  /// `email|language` for every reset asked for.
  final List<String> resets = <String>[];

  @override
  Future<void> sendPasswordReset({
    required String email,
    required String languageCode,
  }) async {
    final AuthFailure? f = failure;
    if (f != null) throw f;
    resets.add('$email|$languageCode');
  }

  final List<String> languages = <String>[];

  @override
  Future<void> saveLanguage(String languageCode) async =>
      languages.add(languageCode);

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<UserModel> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    updates++;
    user = user.copyWith(fullName: fullName, phone: phone);
    _changes.add(null);
    return user;
  }
}

/// Signing out's push clean-up, counted.
class _Device implements DeviceRegistration {
  int unregisters = 0;

  @override
  Future<void> unregister() async => unregisters++;
}

/// The notification permission, as a phone would answer.
class _Push extends Fake implements PushNotifications {
  PushPermission answer = PushPermission.notAsked;
  int requests = 0;

  @override
  Future<PushPermission> permission() async => answer;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return answer = PushPermission.allowed;
  }
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late _Repository repository;
  late AppNotifier notices;
  late _Device device;
  late _Push push;
  late MemoryCountryRepository countries;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': 'en',
      'prefs.onboardingCompleted': true,
      'prefs.themeMode': 'dark',
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    repository = _Repository();
    notices = AppNotifier();
    device = _Device();
    push = _Push();
    countries = MemoryCountryRepository();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<AuthCubit>(() => AuthCubit(repository))
      ..registerFactory<PasswordResetCubit>(
        () => PasswordResetCubit(repository),
      )
      ..registerFactory<AccountCubit>(() => AccountCubit(repository, device))
      ..registerFactory<PushPermissionCubit>(() => PushPermissionCubit(push))
      ..registerFactory<CountryCubit>(() => CountryCubit(countries));
  });
  tearDown(sl.reset);

  Future<GoRouter> pumpApp(WidgetTester tester, String start) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final PreferencesCubit prefs = PreferencesCubit(
      AppPreferences(await SharedPreferences.getInstance()),
    );
    addTearDown(prefs.close);
    GoRoute route(String name, Widget page) =>
        GoRoute(path: '/$name', name: name, builder: (_, _) => page);
    final GoRouter router = GoRouter(
      initialLocation: '/$start',
      routes: <RouteBase>[
        route(AppRoutes.welcome, const Scaffold(body: Text('welcome'))),
        route(AppRoutes.home, const Scaffold(body: Text('home'))),
        route(AppRoutes.login, const LoginPage()),
        route(AppRoutes.register, const RegisterPage()),
        GoRoute(
          path: '/${AppRoutes.forgotPassword}',
          name: AppRoutes.forgotPassword,
          builder: (_, GoRouterState state) =>
              ForgotPasswordPage(email: state.extra as String? ?? ''),
        ),
        route(AppRoutes.profile, const ProfilePage()),
        route(AppRoutes.editProfile, const EditProfilePage()),
        route(AppRoutes.settings, const SettingsPage()),
        route(AppRoutes.about, const AboutPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        assetLoader: const AppAssetLoader(),
        child: BlocProvider<PreferencesCubit>.value(
          value: prefs,
          child: ScreenUtilInit(
            designSize: const Size(AppDesign.width, AppDesign.height),
            builder: (BuildContext context, _) => MaterialApp.router(
              theme: ThemeData(
                extensions: const <ThemeExtension<dynamic>>[AppColors.light],
              ),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (_, Widget? child) =>
                  NotificationHost(notifier: notices, child: child!),
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> type(WidgetTester tester, int field, String text) =>
      tester.enterText(find.byType(TextFormField).at(field), text);

  Future<void> tapText(WidgetTester tester, String key) async {
    await tester.tap(find.text(key.tr()).last);
    await tester.pumpAndSettle();
  }

  /// Lets a notification's own timer run out, so no timer outlives a test.
  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  group('login', () {
    Future<void> fill(WidgetTester tester) async {
      await type(tester, 0, 'Sara@Example.com');
      await type(tester, 1, 'Secret123');
    }

    // Register has had one since batch 2; login is pushed the same way.
    testWidgets('a visible back control returns to welcome', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.welcome);
      router.pushNamed(AppRoutes.login);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(router.state.name, AppRoutes.welcome);
    });

    testWidgets('success goes home', (WidgetTester tester) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.login);
      await fill(tester);
      await tapText(tester, 'auth.login.submit');
      expect(router.state.name, AppRoutes.home);
    });

    // One message for a wrong email or password: nothing tells which emails
    // have accounts.
    testWidgets('wrong credentials show under the password; the email stays', (
      WidgetTester tester,
    ) async {
      repository.failure = const AuthFailure(
        AuthFailureCode.invalidCredentials,
      );
      await pumpApp(tester, AppRoutes.login);
      await fill(tester);
      await tapText(tester, 'auth.login.submit');

      expect(find.text('auth.errors.invalidCredentials'.tr()), findsOneWidget);
      expect(find.text('Sara@Example.com'), findsOneWidget);
      expect(notices.current, isNull);

      await type(tester, 1, 'Secret1234');
      await tester.pump();
      expect(find.text('auth.errors.invalidCredentials'.tr()), findsNothing);
    });

    testWidgets('no connection is a notification; nothing else changes', (
      WidgetTester tester,
    ) async {
      repository.failure = const AuthFailure(AuthFailureCode.network);
      final GoRouter router = await pumpApp(tester, AppRoutes.login);
      await fill(tester);
      await tapText(tester, 'auth.login.submit');

      expect(router.state.name, AppRoutes.login);
      expect(notices.current?.kind, AppNotificationKind.error);
      expect(find.text('auth.errors.network'.tr()), findsOneWidget);
      expect(find.text('Sara@Example.com'), findsOneWidget);
      await outlast(tester);
    });

    testWidgets('while it runs, a second tap does not submit again', (
      WidgetTester tester,
    ) async {
      repository.pending = Completer<UserModel>();
      await pumpApp(tester, AppRoutes.login);
      await fill(tester);
      await tester.tap(find.text('auth.login.submit'.tr()));
      await tester.pump();
      await tester.tap(
        find.text('auth.login.submit'.tr()),
        warnIfMissed: false,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(repository.submits, 1);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
      repository.pending!.complete(_sara);
      await tester.pumpAndSettle();
    });

    testWidgets('forgot password sends a reset link in the app language', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.login);
      await type(tester, 0, 'Sara@Example.com');
      await tapText(tester, 'auth.login.forgotPassword');
      expect(router.state.name, AppRoutes.forgotPassword);
      // The email typed on login comes along.
      expect(find.text('Sara@Example.com'), findsOneWidget);

      await tapText(tester, 'auth.reset.send');
      expect(repository.resets, <String>['Sara@Example.com|en']);
      // The same words whether or not the email has an account.
      expect(find.text('auth.reset.sent'.tr()), findsOneWidget);
      expect(find.text('auth.reset.send'.tr()), findsNothing);

      await tapText(tester, 'auth.reset.back');
      expect(router.state.name, AppRoutes.login);
    });

    testWidgets('a reset with a malformed email never leaves the phone', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, AppRoutes.login);
      await tapText(tester, 'auth.login.forgotPassword');
      await tapText(tester, 'auth.reset.send');
      expect(repository.resets, isEmpty);
      expect(find.text('validation.required'.tr()), findsOneWidget);
    });
  });

  group('register', () {
    Future<void> fill(WidgetTester tester) async {
      await type(tester, 0, 'Sara Ahmed');
      await type(tester, 1, 'sara@example.com');
      await type(tester, 3, 'Secret123');
      await type(tester, 4, 'Secret123');
    }

    testWidgets('success signs in, says where the account lives, goes home', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.register);
      await fill(tester);
      await tester.ensureVisible(find.text('auth.register.submit'.tr()));
      await tapText(tester, 'auth.register.submit');

      expect(router.state.name, AppRoutes.home);
      expect(notices.current?.kind, AppNotificationKind.success);
      expect(find.text('auth.notices.registered.message'.tr()), findsOneWidget);
      await outlast(tester);
    });

    testWidgets('a taken email shows under the email field', (
      WidgetTester tester,
    ) async {
      repository.failure = const AuthFailure(AuthFailureCode.emailTaken);
      final GoRouter router = await pumpApp(tester, AppRoutes.register);
      await fill(tester);
      await tester.ensureVisible(find.text('auth.register.submit'.tr()));
      await tapText(tester, 'auth.register.submit');

      expect(router.state.name, AppRoutes.register);
      expect(find.text('auth.errors.emailTaken'.tr()), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(notices.current, isNull);
    });

    testWidgets('an invalid form never reaches the repository', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, AppRoutes.register);
      await type(tester, 1, 'not-an-email');
      await tester.ensureVisible(find.text('auth.register.submit'.tr()));
      await tapText(tester, 'auth.register.submit');

      expect(repository.submits, 0);
      expect(find.text('validation.email'.tr()), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('shows the account, kept in the account, phone unverified', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, AppRoutes.profile);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('sara@example.com'), findsOneWidget);
      expect(find.text('profile.accountNote'.tr()), findsOneWidget);
      expect(
        find.textContaining('profile.phoneUnverified'.tr()),
        findsOneWidget,
      );
    });

    testWidgets('sign-out asks first; cancel keeps the session', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.profile);
      await tester.ensureVisible(find.text('profile.signOut'.tr()));
      await tapText(tester, 'profile.signOut');
      expect(find.text('profile.confirm.message'.tr()), findsOneWidget);

      await tapText(tester, 'profile.confirm.cancel');
      expect(repository.logouts, 0);
      expect(router.state.name, AppRoutes.profile);
    });

    testWidgets('confirmed, it signs out to welcome and keeps preferences', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.profile);
      await tester.ensureVisible(find.text('profile.signOut'.tr()));
      await tapText(tester, 'profile.signOut');
      await tester.tap(find.text('profile.confirm.confirm'.tr()).last);
      await tester.pumpAndSettle();

      expect(repository.logouts, 1);
      expect(device.unregisters, 1);
      expect(router.state.name, AppRoutes.welcome);
      expect(notices.current?.title, 'auth.notices.signedOut.title'.tr());
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('prefs.onboardingCompleted'), isTrue);
      expect(prefs.getString('prefs.themeMode'), 'dark');
      expect(prefs.getString('locale'), 'en');
      await outlast(tester);
    });

    testWidgets('an edit is validated, saved, and shown on the profile', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.profile);
      await tapText(tester, 'profile.edit');
      expect(router.state.name, AppRoutes.editProfile);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('profile.editPage.emailNote'.tr()), findsOneWidget);

      await type(tester, 0, ' ');
      await tapText(tester, 'profile.editPage.save');
      expect(repository.updates, 0);
      expect(find.text('validation.fullName'.tr()), findsOneWidget);

      await type(tester, 0, 'Sara Al-Harbi');
      await type(tester, 1, '');
      await tapText(tester, 'profile.editPage.save');

      expect(repository.updates, 1);
      expect(router.state.name, AppRoutes.profile);
      expect(find.text('Sara Al-Harbi'), findsOneWidget);
      expect(find.text('sara@example.com'), findsOneWidget);
      expect(notices.current?.title, 'profile.notices.updated'.tr());
      await outlast(tester);
    });

    testWidgets('settings change the theme at once and keep it', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.profile);
      await tapText(tester, 'profile.settings.title');
      expect(router.state.name, AppRoutes.settings);
      expect(find.text('preferences.language'.tr()), findsOneWidget);

      await tapText(tester, 'preferences.themes.light');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('prefs.themeMode'), 'light');
    });

    testWidgets('the country row asks, then shows and changes the country', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, AppRoutes.profile);
      final Finder row = find.text('country.title'.tr());
      await tester.ensureVisible(row);
      expect(find.text('country.notChosen'.tr()), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('country.picker.title'.tr()), findsOneWidget);
      await tester.tap(find.text('Egypt'));
      await tester.pumpAndSettle();
      expect(countries.code, 'EG');
      expect(find.text('🇪🇬  Egypt'), findsOneWidget);
    });

    testWidgets('about says where information is kept and what is not built', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pumpApp(tester, AppRoutes.profile);
      await tester.ensureVisible(find.text('profile.about.title'.tr()));
      await tapText(tester, 'profile.about.title');
      expect(router.state.name, AppRoutes.about);
      expect(find.text('about.stored.title'.tr()), findsOneWidget);
      expect(find.text('about.stored.route'.tr()), findsOneWidget);
      // The list is lazy: bring the second section into view.
      await tester.scrollUntilVisible(
        find.text('about.notYet.title'.tr()),
        200,
      );
      expect(find.text('about.notYet.title'.tr()), findsOneWidget);
      expect(find.text('about.notYet.alerts'.tr()), findsOneWidget);
    });

    // The only place the app asks for the permission, and only on a tap.
    testWidgets('the notifications row asks only when tapped', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, AppRoutes.profile);
      await tester.ensureVisible(find.text('profile.notifications.title'.tr()));
      expect(find.text('profile.notifications.notAsked'.tr()), findsOneWidget);
      expect(push.requests, 0);

      await tapText(tester, 'profile.notifications.title');
      expect(push.requests, 1);
      expect(find.text('profile.notifications.allowed'.tr()), findsOneWidget);
    });

    testWidgets('a refused permission is explained, never asked again', (
      WidgetTester tester,
    ) async {
      push.answer = PushPermission.blocked;
      await pumpApp(tester, AppRoutes.profile);
      await tester.ensureVisible(find.text('profile.notifications.title'.tr()));
      await tapText(tester, 'profile.notifications.title');
      expect(push.requests, 0);
      expect(notices.current?.message, 'profile.notifications.howToAllow'.tr());
      await outlast(tester);
    });

    testWidgets('a language chosen in settings is kept with the account', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, AppRoutes.settings);
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(repository.languages, <String>['ar']);
    });
  });
}
