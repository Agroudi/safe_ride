import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_back_dispatcher.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_router.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Pins the go_router / Navigator behaviour the route transitions rest on —
/// a `go` keeps the old page painted while its secondary animation runs — and
/// what each recipe draws on the way.
const Map<String, String> _paths = <String, String>{
  AppRoutes.splash: AppRoutes.splashPath,
  AppRoutes.welcome: AppRoutes.welcomePath,
  AppRoutes.home: AppRoutes.homePath,
  AppRoutes.login: AppRoutes.loginPath,
  AppRoutes.register: AppRoutes.registerPath,
  AppRoutes.planJourney: AppRoutes.planJourneyPath,
};

/// Pushed in the app, so built with [AppPages.task]; the rest are stages.
const Set<String> _tasks = <String>{
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.planJourney,
};

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  String start = AppRoutes.splash,
  TextDirection direction = TextDirection.ltr,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: _paths[start],
    routes: <RouteBase>[
      for (final MapEntry<String, String> route in _paths.entries)
        GoRoute(
          path: route.value,
          name: route.key,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              (_tasks.contains(route.key) ? AppPages.task : AppPages.stage)(
                context,
                state,
                Scaffold(
                  body: SizedBox.expand(
                    key: ValueKey<String>(route.key),
                    child: Text(route.key),
                  ),
                ),
              ),
        ),
    ],
  );
  addTearDown(router.dispose);
  final AppNotifier notices = AppNotifier();
  addTearDown(notices.dispose);
  final AppBackButtonDispatcher dispatcher = AppBackButtonDispatcher(
    router: router,
    notifier: notices,
  );

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(AppDesign.width, AppDesign.height),
      builder: (_, _) => MaterialApp.router(
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[AppColors.light],
        ),
        builder: (BuildContext context, Widget? child) =>
            Directionality(textDirection: direction, child: child!),
        routerDelegate: router.routerDelegate,
        routeInformationParser: router.routeInformationParser,
        routeInformationProvider: router.routeInformationProvider,
        backButtonDispatcher: dispatcher,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _page(String name) => find.byKey(ValueKey<String>(name));

/// What the page is drawn at: every fade above it, multiplied.
double _opacity(WidgetTester tester, String name) => tester
    .widgetList<FadeTransition>(
      find.ancestor(of: _page(name), matching: find.byType(FadeTransition)),
    )
    .fold(1, (double o, FadeTransition fade) => o * fade.opacity.value);

/// Where the page is painted; its layout always starts at the origin.
double _x(WidgetTester tester, String name) =>
    tester.getTopLeft(_page(name)).dx;

ModalRoute<dynamic> _route(WidgetTester tester, String name) =>
    ModalRoute.of(tester.element(_page(name)))!;

/// Navigates, then pumps the frame that starts the transition, so later
/// pumps are measured from its t = 0.
Future<void> _start(WidgetTester tester, VoidCallback navigate) async {
  navigate();
  await tester.pump();
}

void main() {
  group('a go between stages', () {
    testWidgets('keeps the old page mounted while its secondary runs', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpApp(tester);
      await _start(tester, () => router.goNamed(AppRoutes.welcome));

      final List<double> secondary = <double>[];
      for (int i = 0; i < 4; i++) {
        expect(_page(AppRoutes.splash), findsOneWidget, reason: '${i * 100}');
        secondary.add(
          _route(tester, AppRoutes.splash).secondaryAnimation!.value,
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(secondary.first, 0);
      for (int i = 1; i < secondary.length; i++) {
        expect(secondary[i], greaterThan(secondary[i - 1]));
      }
      await tester.pumpAndSettle();
      expect(_page(AppRoutes.splash), findsNothing);
      expect(_opacity(tester, AppRoutes.welcome), 1);
    });

    testWidgets('fades out by 140 ms and in from 120 ms', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpApp(tester);
      await _start(tester, () => router.goNamed(AppRoutes.welcome));

      await tester.pump(const Duration(milliseconds: 120));
      expect(_opacity(tester, AppRoutes.splash), greaterThan(0));
      expect(_opacity(tester, AppRoutes.welcome), moreOrLessEquals(0));

      await tester.pump(const Duration(milliseconds: 20));
      expect(_opacity(tester, AppRoutes.splash), moreOrLessEquals(0));
      expect(_opacity(tester, AppRoutes.welcome), greaterThan(0));

      // A stage never moves: right whether the user went forward or up.
      expect(_x(tester, AppRoutes.welcome), 0);
      expect(_x(tester, AppRoutes.splash), 0);
      await tester.pumpAndSettle();
    });
  });

  group('a task push enters from the end side', () {
    // +1: the end side is on the right; −1: on the left.
    for (final (TextDirection direction, double end)
        in <(TextDirection, double)>[
          (TextDirection.ltr, 1),
          (TextDirection.rtl, -1),
        ]) {
      testWidgets('in ${direction.name}', (WidgetTester tester) async {
        final GoRouter router = await _pumpApp(
          tester,
          start: AppRoutes.welcome,
          direction: direction,
        );
        await _start(tester, () => router.pushNamed(AppRoutes.login));

        await tester.pump(const Duration(milliseconds: 100));
        expect(_x(tester, AppRoutes.login) * end, greaterThan(1));
        // The covered page only fades.
        expect(_x(tester, AppRoutes.welcome), 0);
        await tester.pumpAndSettle();
        expect(_x(tester, AppRoutes.login), 0);

        // A pop leaves toward the same side. The travel is `enter` run
        // backwards, so it barely moves at first: look while it still shows.
        await _start(tester, router.pop);
        await tester.pump(const Duration(milliseconds: 200));
        expect(_opacity(tester, AppRoutes.login), greaterThan(0));
        expect(_x(tester, AppRoutes.login) * end, greaterThan(0));
        await tester.pumpAndSettle();
        expect(_page(AppRoutes.login), findsNothing);
      });
    }
  });

  // Every "up" today lands on a stage page (welcome, home); the marker keeps
  // a future task target from arriving as if it were forward.
  testWidgets('"up" into a task page arrives with the stage fade', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(
      tester,
      start: AppRoutes.planJourney,
    );

    await _start(
      tester,
      () => router.goNamed(AppRoutes.login, extra: AppPages.up),
    );

    expect(router.state.name, AppRoutes.login);
    expect(router.state.extra, AppPages.up);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_x(tester, AppRoutes.login), 0);
    expect(_opacity(tester, AppRoutes.login), moreOrLessEquals(0));
    await tester.pumpAndSettle();
    expect(_opacity(tester, AppRoutes.login), 1);
  });

  testWidgets('the same task route pushed normally still slides', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpApp(tester, start: AppRoutes.welcome);
    await _start(tester, () => router.goNamed(AppRoutes.login));

    await tester.pump(const Duration(milliseconds: 100));
    expect(router.state.extra, isNull);
    expect(_x(tester, AppRoutes.login), greaterThan(1));
    await tester.pumpAndSettle();
  });

  group('under reduced motion', () {
    setUp(() {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
    });
    tearDown(
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .clearAccessibilityFeaturesTestValue,
    );

    testWidgets('a go cuts', (WidgetTester tester) async {
      final GoRouter router = await _pumpApp(tester);
      await _start(tester, () => router.goNamed(AppRoutes.welcome));
      await tester.pump();

      final TransitionRoute<dynamic> route =
          _route(tester, AppRoutes.welcome) as TransitionRoute<dynamic>;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      expect(_page(AppRoutes.splash), findsNothing);
      expect(_opacity(tester, AppRoutes.welcome), 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a push cuts, with no travel', (WidgetTester tester) async {
      final GoRouter router = await _pumpApp(tester, start: AppRoutes.welcome);
      await _start(tester, () => router.pushNamed(AppRoutes.login));

      final TransitionRoute<dynamic> route =
          _route(tester, AppRoutes.login) as TransitionRoute<dynamic>;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      expect(_x(tester, AppRoutes.login), 0);
      expect(_opacity(tester, AppRoutes.login), 1);
    });
  });

  // One page type for every route: a `builder:` route (a MaterialPage) over a
  // custom page silently drops the covered page's exit.
  testWidgets('every app route is built by a pageBuilder', (
    WidgetTester tester,
  ) async {
    // Every route, the tab shell's branches included.
    final List<GoRoute> routes = <GoRoute>[];
    void walk(List<RouteBase> level) {
      for (final RouteBase route in level) {
        switch (route) {
          case GoRoute():
            routes.add(route);
            walk(route.routes);
          case StatefulShellRoute():
            expect(route.pageBuilder, isNotNull, reason: 'the tab shell');
            expect(route.builder, isNull, reason: 'the tab shell');
            for (final StatefulShellBranch branch in route.branches) {
              walk(branch.routes);
            }
          default:
            fail('unexpected route type ${route.runtimeType}');
        }
      }
    }

    walk(AppRouter.router.configuration.routes);
    expect(routes, hasLength(22));
    for (final GoRoute route in routes) {
      expect(route.pageBuilder, isNotNull, reason: route.name);
      expect(route.builder, isNull, reason: route.name);
    }
  });
}
