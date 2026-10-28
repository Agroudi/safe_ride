import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_back_dispatcher.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every route under its real name and path. The pages only print the name:
/// enough to see where a back gesture lands, without the theme, the fonts or
/// the screens themselves.
const Map<String, String> _paths = <String, String>{
  AppRoutes.splash: AppRoutes.splashPath,
  AppRoutes.onboarding: AppRoutes.onboardingPath,
  AppRoutes.welcome: AppRoutes.welcomePath,
  AppRoutes.login: AppRoutes.loginPath,
  AppRoutes.register: AppRoutes.registerPath,
  AppRoutes.home: AppRoutes.homePath,
  AppRoutes.myJourneys: AppRoutes.myJourneysPath,
  AppRoutes.profile: AppRoutes.profilePath,
  AppRoutes.planJourney: AppRoutes.planJourneyPath,
  AppRoutes.reviewJourney: AppRoutes.reviewJourneyPath,
};

/// The notifier the last `_pumpApp` handed its dispatcher: the "press back
/// again" notice is read from it, not from pixels.
late AppNotifier _notices;

/// Pumps an app wired the way `App` wires it — the router in pieces, the real
/// dispatcher, a notifier, real translations — opened on [start] with
/// nothing underneath it, as a `go` leaves it. [pages] replaces the stand-in
/// page of a route; [clock] replaces the dispatcher's wall clock.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required String start,
  Locale locale = AppLocales.english,
  Map<String, Widget> pages = const <String, Widget>{},
  DateTime Function() clock = DateTime.now,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: _paths[start],
    routes: <RouteBase>[
      for (final MapEntry<String, String> route in _paths.entries)
        GoRoute(
          path: route.value,
          name: route.key,
          builder: (_, _) =>
              pages[route.key] ?? Scaffold(body: Text(route.key)),
        ),
    ],
  );
  addTearDown(router.dispose);
  _notices = AppNotifier();
  addTearDown(_notices.dispose);
  // Built once, outside the builder, as `App` does: a rebuilt dispatcher would
  // forget the "press back again" moment.
  final AppBackButtonDispatcher dispatcher = AppBackButtonDispatcher(
    router: router,
    notifier: _notices,
    clock: clock,
  );

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      fallbackLocale: AppLocales.fallback,
      startLocale: locale,
      saveLocale: false,
      path: AppLocales.translationsPath,
      child: Builder(
        builder: (BuildContext context) => MaterialApp.router(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          routerDelegate: router.routerDelegate,
          routeInformationParser: router.routeInformationParser,
          routeInformationProvider: router.routeInformationProvider,
          backButtonDispatcher: dispatcher,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The system back gesture from the engine's `popRoute` onwards — so this
/// also proves the dispatcher is the one wired in. It does not cover whether
/// Android sends `popRoute` at all; the manifest test below guards that.
Future<bool> _back(WidgetTester tester) async {
  final bool handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

/// Counts `SystemNavigator.pop` — the call that closes the app.
ValueGetter<int> _countAppExits(WidgetTester tester) {
  int exits = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return () => exits;
}

/// `app.exitConfirm` read from the translation file itself, so a missing key
/// (which easy_localization would show as the raw key) fails the test.
String _exitConfirm(Locale locale) {
  final File file = File(
    '${AppLocales.translationsPath}/${locale.languageCode}.json',
  );
  final Map<String, dynamic> json =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (json['app'] as Map<String, dynamic>)['exitConfirm'] as String;
}

void main() {
  setUpAll(() async {
    // easy_localization logs every build; the assertions say what matters.
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  // ⚠️ The asset bundle caches each file as a Future that belongs to the
  // first test's fake-async zone. A later test awaiting it never resumes, so
  // the translations never load and the app never builds.
  setUp(rootBundle.clear);

  group('a screen with nothing to pop goes up', () {
    const Map<String, String> up = <String, String>{
      AppRoutes.login: AppRoutes.welcome,
      AppRoutes.register: AppRoutes.welcome,
      AppRoutes.myJourneys: AppRoutes.home,
      AppRoutes.profile: AppRoutes.home,
      AppRoutes.planJourney: AppRoutes.home,
      AppRoutes.reviewJourney: AppRoutes.planJourney,
    };

    for (final MapEntry<String, String> step in up.entries) {
      testWidgets('${step.key} → ${step.value}', (WidgetTester tester) async {
        final ValueGetter<int> exits = _countAppExits(tester);
        final GoRouter router = await _pumpApp(tester, start: step.key);

        expect(await _back(tester), isTrue);

        expect(router.state.name, step.value);
        expect(find.text(step.value), findsOneWidget);
        expect(_notices.current, isNull);
        expect(exits(), 0);
      });
    }
  });

  // The router is asked first: a screen that was pushed pops to whatever is
  // under it, even where `_up` would name a different screen.
  testWidgets('a pushed screen pops to the one beneath it', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester, start: AppRoutes.home);
    router.pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();

    await _back(tester);

    expect(router.state.name, AppRoutes.home);
  });

  // What onboarding relies on: its `PopScope` turns back into "previous
  // step". The router reports the gesture handled, so the dispatcher neither
  // goes up nor warns — the page alone decides.
  testWidgets('a page that holds its own pop keeps the gesture', (
    WidgetTester tester,
  ) async {
    final ValueGetter<int> appExits = _countAppExits(tester);
    int held = 0;
    final GoRouter router = await _pumpApp(
      tester,
      start: AppRoutes.onboarding,
      pages: <String, Widget>{
        AppRoutes.onboarding: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (!didPop) held++;
          },
          child: const Scaffold(body: Text(AppRoutes.onboarding)),
        ),
      },
    );

    expect(await _back(tester), isTrue);
    expect(await _back(tester), isTrue);

    expect(held, 2);
    expect(router.state.name, AppRoutes.onboarding);
    expect(_notices.current, isNull);
    expect(appExits(), 0);
  });

  // ⚠️ On Android 16 with targetSdk 36, predictive back is on unless the
  // manifest opts out, and then the OS takes back itself whenever the root
  // route cannot pop: `popRoute` never arrives and every test above passes
  // while the phone closes the app. Re-test on a device before removing it.
  test('the manifest routes every back through the dispatcher', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final RegExpMatch? application = RegExp(
      r'<application\s[^>]*>',
    ).firstMatch(manifest);

    expect(application, isNotNull);
    expect(
      application![0],
      contains('android:enableOnBackInvokedCallback="false"'),
    );
  });

  group('at an end of the road', () {
    const List<String> exits = <String>[
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.welcome,
      AppRoutes.home,
    ];

    for (final String screen in exits) {
      testWidgets('$screen: the first back warns and stays', (
        WidgetTester tester,
      ) async {
        final ValueGetter<int> appExits = _countAppExits(tester);
        final GoRouter router = await _pumpApp(tester, start: screen);

        expect(await _back(tester), isTrue);

        expect(_notices.current?.title, _exitConfirm(AppLocales.english));
        expect(router.state.name, screen);
        expect(appExits(), 0);
      });

      testWidgets('$screen: a second back in the window leaves', (
        WidgetTester tester,
      ) async {
        final ValueGetter<int> appExits = _countAppExits(tester);
        final GoRouter router = await _pumpApp(tester, start: screen);

        await _back(tester);
        expect(await _back(tester), isTrue);

        expect(appExits(), 1);
        expect(router.state.name, screen);
      });
    }

    // The offer expires with the line that makes it: a second back after
    // the window is a first back again.
    testWidgets('a second back after the window warns again', (
      WidgetTester tester,
    ) async {
      final ValueGetter<int> appExits = _countAppExits(tester);
      DateTime now = DateTime.utc(2026);
      await _pumpApp(tester, start: AppRoutes.welcome, clock: () => now);

      await _back(tester);
      now = now.add(AppDurations.exitWindow + const Duration(milliseconds: 1));
      expect(await _back(tester), isTrue);

      expect(appExits(), 0);
      expect(_notices.current?.title, _exitConfirm(AppLocales.english));

      // …and that second warning re-arms the window.
      now = now.add(AppDurations.exitWindow);
      await _back(tester);
      expect(appExits(), 1);
    });

    testWidgets('the warning follows the language', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        start: AppRoutes.welcome,
        locale: AppLocales.arabic,
      );

      await _back(tester);

      expect(_notices.current?.title, _exitConfirm(AppLocales.arabic));
    });
  });
}
