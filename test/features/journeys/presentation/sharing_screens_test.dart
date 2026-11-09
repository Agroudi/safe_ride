import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/constants/app_asset_loader.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/location_sharing.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';
import 'package:safe_ride/features/journeys/data/repository/shared_view_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/share_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/shared_view_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/pages/shared_view_page.dart';
import 'package:safe_ride/features/journeys/presentation/pages/sharing_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara Ahmed');
}

class _FakeView implements SharedViewRepository {
  final StreamController<SharedViewEvent> events =
      StreamController<SharedViewEvent>.broadcast();

  @override
  Stream<SharedViewEvent> watch(String token) => events.stream;

  @override
  Future<List<SharedRoutePoint>> chunk(String token, int chunk) async =>
      const <SharedRoutePoint>[];
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late FakeShares shares;
  late FakeShareLinks links;
  late FakeLocation location;
  late LocationSharing sharing;
  late JourneyTracker tracker;
  late _FakeView view;
  final String token = BearerToken.generate(Random(1));

  Future<void> boot(String language) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    final _Session session = _Session();
    final FirestoreJourneyRepository journeys = FirestoreJourneyRepository(
      FakeFirebaseFirestore(),
      session,
    );
    shares = FakeShares();
    links = FakeShareLinks();
    location = FakeLocation(now: LocationAccess.granted);
    view = _FakeView();
    tracker = JourneyTracker(
      location: location,
      store: MemoryTrackStore(),
      route: FakeRoute(),
      journeys: journeys,
      session: session,
      translate: (String k) => k,
      tickEvery: const Duration(days: 1),
    );
    sharing = LocationSharing(
      tracker: tracker,
      shares: shares,
      journeys: journeys,
      session: session,
      links: links,
      tickEvery: const Duration(days: 1),
    );
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(AppNotifier())
      ..registerSingleton<MapTileProvider>(FakeMapTiles())
      ..registerFactory<ShareCubit>(
        () => ShareCubit(sharing, tracker, journeys),
      )
      ..registerFactory<SharedViewCubit>(
        () => SharedViewCubit(view, checkEvery: const Duration(days: 1)),
      );
  }

  tearDown(sl.reset);

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> show(
    WidgetTester tester,
    Widget home, {
    bool dark = false,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        assetLoader: const AppAssetLoader(),
        child: ScreenUtilInit(
          designSize: const Size(AppDesign.width, AppDesign.height),
          builder: (BuildContext context, _) => MaterialApp(
            theme: ThemeData(
              extensions: <ThemeExtension<dynamic>>[
                dark ? AppColors.dark : AppColors.light,
              ],
            ),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (_, Widget? child) =>
                NotificationHost(notifier: sl<AppNotifier>(), child: child!),
            home: home,
          ),
        ),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  /// Brings [text] on screen: a list builds ahead of what it shows.
  Future<void> reach(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 300);
    await tester.ensureVisible(find.text(text));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Leaves no timers behind.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 9));
    await tester.runAsync(() async {
      await sharing.dispose();
      await tracker.dispose();
    });
  }

  group('the owner', () {
    testWidgets('says what is shared before anything starts', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, const SharingPage());
      expect(find.text('Share my location'), findsOneWidget);
      expect(find.text('Anyone with the link can see'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.textContaining('Until the journey'), findsNothing);
      expect(shares.saved, isEmpty);
      await finish(tester);
    });

    testWidgets('a journey offers "until it finishes" first', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, const SharingPage(journeyId: 'j1'));
      expect(find.text('Share this journey'), findsOneWidget);
      expect(find.textContaining('Until the journey'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('after Start: on, until when, and the link\'s actions', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, const SharingPage());
      await reach(tester, 'Start sharing');
      await tester.tap(find.text('Start sharing'));
      await settle(tester);
      await settle(tester);
      expect(find.text('Manage sharing'), findsOneWidget);
      expect(find.text("You're sharing your location."), findsOneWidget);
      expect(find.text('Waiting for your location'), findsOneWidget);
      expect(find.textContaining('Ends at'), findsOneWidget);
      expect(find.text('Send the link'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Stop sharing'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('no link is offered when it could not work', (
      WidgetTester tester,
    ) async {
      await boot('en');
      links.viewer = false;
      await show(tester, const SharingPage());
      await reach(tester, 'Start sharing');
      await tester.tap(find.text('Start sharing'));
      await settle(tester);
      expect(find.text("Sharing isn't available yet"), findsOneWidget);
      expect(find.text('Copy link'), findsNothing);
      await finish(tester);
    });

    testWidgets('stopping asks first, then the link is gone', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, const SharingPage());
      await reach(tester, 'Start sharing');
      await tester.tap(find.text('Start sharing'));
      await settle(tester);
      await settle(tester);
      await reach(tester, 'Stop sharing');
      await tester.tap(find.text('Stop sharing'));
      await settle(tester);
      expect(find.text('Stop sharing?'), findsOneWidget);
      expect(shares.stopped, isEmpty);
      await tester.tap(find.text('Stop sharing').last);
      await settle(tester);
      expect(shares.stopped, hasLength(1));
      expect(sharing.current, isNull);
      await finish(tester);
    });

    testWidgets('in Arabic, dark, at large text, nothing overflows', (
      WidgetTester tester,
    ) async {
      await boot('ar');
      await show(tester, const SharingPage(), dark: true, textScale: 2);
      expect(find.text('شارك موقعي'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  });

  group('the recipient', () {
    SharedView shared({
      DateTime? at,
      String tracking = 'live',
      bool finished = false,
    }) => SharedView(
      kind: 'journey',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      tracking: tracking,
      point: finished ? null : const LatLng(24.7, 46.68),
      locationAt: finished ? null : at ?? DateTime.now().toUtc(),
      origin: const SharedPlace(name: 'Home', lat: 24.7, lng: 46.68),
      destination: const SharedPlace(name: 'Work'),
      distanceMeters: 1200,
      finished: finished,
    );

    Future<void> send(WidgetTester tester, SharedViewEvent e) async {
      view.events.add(e);
      await settle(tester);
    }

    testWidgets('a live share: the map, the status, the update time', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, SharedViewPage(token: token));
      await send(tester, SharedViewEvent(view: shared()));
      expect(find.text('Live'), findsOneWidget);
      expect(find.textContaining('Last updated at'), findsOneWidget);
      expect(find.textContaining('Travelled'), findsOneWidget);
      expect(find.textContaining('Link ends at'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('an old position is never called live', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, SharedViewPage(token: token));
      await send(
        tester,
        SharedViewEvent(
          view: shared(
            at: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          ),
        ),
      );
      expect(find.text('Live'), findsNothing);
      expect(find.text('Not up to date'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('offline it says so, and keeps what it had', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, SharedViewPage(token: token));
      await send(tester, SharedViewEvent(view: shared()));
      await send(tester, SharedViewEvent(view: shared(), offline: true));
      expect(find.text('Live'), findsNothing);
      expect(find.text("You're offline: not up to date"), findsOneWidget);
      await finish(tester);
    });

    testWidgets('paused and finished are said plainly', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, SharedViewPage(token: token));
      await send(tester, SharedViewEvent(view: shared(tracking: 'paused')));
      expect(find.text('Location unavailable'), findsOneWidget);
      await send(tester, SharedViewEvent(view: shared(finished: true)));
      expect(find.text('Journey finished'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a stopped share says it has ended', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, SharedViewPage(token: token));
      await send(tester, SharedViewEvent(view: shared()));
      await send(tester, const SharedViewEvent(ended: true));
      expect(find.text('This share has ended'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
      await finish(tester);
    });

    testWidgets('a bad link says the same, and reads nothing', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, const SharedViewPage(token: null));
      expect(find.text('This share has ended'), findsOneWidget);
      expect(view.events.hasListener, isFalse);
      await finish(tester);
    });

    testWidgets('back works with nothing beneath: a link opens it cold', (
      WidgetTester tester,
    ) async {
      await boot('en');
      final GoRouter router = GoRouter(
        initialLocation: '/s',
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.splashPath,
            name: AppRoutes.splash,
            builder: (_, _) => const Text('the splash decides'),
          ),
          GoRoute(
            path: AppRoutes.sharedViewPath,
            builder: (_, _) => const SharedViewPage(token: null),
          ),
        ],
      );
      await show(tester, Router.withConfig(config: router));
      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(find.text('the splash decides'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('in Arabic, dark, at large text', (WidgetTester tester) async {
      await boot('ar');
      await show(
        tester,
        SharedViewPage(token: token),
        dark: true,
        textScale: 2,
      );
      await send(tester, SharedViewEvent(view: shared()));
      expect(find.text('مباشر'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  });
}
