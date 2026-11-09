import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/constants/app_asset_loader.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/pages/journey_map_page.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_map_layers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_map_panel.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

/// Follows the theme the test asks for, without rebuilding the page.
class _Themed extends StatefulWidget {
  const _Themed({required this.mode, required this.home});

  final ValueNotifier<ThemeMode> mode;
  final Widget home;

  @override
  State<_Themed> createState() => _ThemedState();
}

class _ThemedState extends State<_Themed> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: widget.mode,
    builder: (_, ThemeMode mode, _) => MaterialApp(
      theme: ThemeData(
        extensions: const <ThemeExtension<dynamic>>[AppColors.light],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
      ),
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: widget.home,
    ),
  );
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late FirestoreJourneyRepository journeys;
  late FakeLocation location;
  late FakeMapTiles tiles;
  late FakeRouting routing;
  late JourneyTracker tracker;
  late ValueNotifier<ThemeMode> mode;
  late DateTime now;
  late JourneyModel journey;

  Future<void> boot(WidgetTester tester, String language) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    final _Session session = _Session();
    journeys = FirestoreJourneyRepository(FakeFirebaseFirestore(), session);
    location = FakeLocation(now: LocationAccess.granted);
    tiles = FakeMapTiles();
    routing = FakeRouting();
    mode = ValueNotifier<ThemeMode>(ThemeMode.light);
    now = DateTime.now().toUtc();
    tracker = JourneyTracker(
      location: location,
      store: MemoryTrackStore(),
      route: FakeRoute(),
      journeys: journeys,
      session: session,
      translate: (String k) => k,
      clock: () => now,
      tickEvery: const Duration(days: 1),
    );
    await sl.reset();
    sl
      ..registerSingleton<MapTileProvider>(tiles)
      ..registerFactory<JourneyMapCubit>(
        () => JourneyMapCubit(
          tracker,
          journeys,
          routing,
          resumedFor: Duration.zero,
        ),
      );
    await tester.runAsync(() async {
      journey = await journeys.plan(
        origin: 'Home',
        destination: 'Work',
        departsAt: DateTime.now().add(const Duration(hours: 1)),
        originPlace: const JourneyPlace(name: 'Home', lat: 24.7, lng: 46.67),
        destinationPlace: const JourneyPlace(
          name: 'Work',
          lat: 24.72,
          lng: 46.67,
        ),
      );
      await journeys.start(
        journey.id,
        checklistVersion: 1,
        confirmed: JourneyChecklist.itemsOf(1).toSet(),
      );
    });
  }

  tearDown(sl.reset);

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1170, 2532),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
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
          builder: (BuildContext context, _) => _Themed(
            mode: mode,
            home: JourneyMapPage(id: journey.id),
          ),
        ),
      ),
    );
    await settle(tester);
    await settle(tester);
    // The recording must be joined before a fix can reach it.
    for (int i = 0; i < 20 && tracker.current == null; i++) {
      await settle(tester);
    }
  }

  Future<void> fix(WidgetTester tester, double metres, {double? speed}) async {
    now = now.add(const Duration(seconds: 2));
    location.fix(24.7 + metres / 111195, 46.67, at: now, speed: speed);
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(tracker.dispose);
  }

  MapCamera camera(WidgetTester tester) =>
      MapCamera.of(tester.element(find.byType(JourneyMapLayers)));

  Finder recenter() => find.byIcon(Icons.location_searching_rounded);
  Finder following() => find.byIcon(Icons.my_location_rounded);

  testWidgets('both ends, the position and the journey panel', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    expect(find.byType(CurrentLocationDot), findsOneWidget);
    expect(find.byType(PlacePin), findsWidgets);
    expect(find.textContaining('Home'), findsOneWidget);
    expect(find.text('Recording'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Travelled'), findsOneWidget);
    expect(find.textContaining('© tiles'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the position and the route follow the fixes', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    await fix(tester, 100);
    await fix(tester, 200);
    final List<Polyline> lines = tester
        .widgetList<PolylineLayer>(find.byType(PolylineLayer))
        .expand((PolylineLayer l) => l.polylines)
        .toList();
    expect(lines.single.points, hasLength(3));
    final Marker you = tester
        .widgetList<MarkerLayer>(find.byType(MarkerLayer))
        .single
        .markers
        .last;
    expect(you.point.latitude, closeTo(24.7 + 200 / 111195, 1e-6));
    expect(camera(tester).center.latitude, closeTo(24.7 + 200 / 111195, 1e-5));
    await finish(tester);
  });

  testWidgets('a gap draws two lines, never one across it', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    await fix(tester, 100);
    now = now.add(const Duration(minutes: 5));
    await fix(tester, 2000);
    await fix(tester, 2100);
    final List<Polyline> lines = tester
        .widgetList<PolylineLayer>(find.byType(PolylineLayer))
        .expand((PolylineLayer l) => l.polylines)
        .toList();
    expect(lines, hasLength(2));
    await finish(tester);
  });

  testWidgets('moving the map stops following; only the button resumes it', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    expect(following(), findsOneWidget);

    await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
    await settle(tester);
    expect(recenter(), findsOneWidget);
    final LatLng moved = camera(tester).center;

    await fix(tester, 100);
    await fix(tester, 200);
    expect(camera(tester).center, moved, reason: 'the user is looking there');

    await tester.tap(recenter());
    await settle(tester);
    expect(following(), findsOneWidget);
    expect(camera(tester).center.latitude, closeTo(24.7 + 200 / 111195, 1e-5));
    await finish(tester);
  });

  testWidgets('zoom buttons work, and stay within follow mode', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    final double zoom = camera(tester).zoom;
    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    expect(camera(tester).zoom, closeTo(zoom + 1, 1e-6));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await settle(tester);
    expect(camera(tester).zoom, closeTo(zoom, 1e-6));
    expect(following(), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a theme change swaps the tiles and nothing else', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    await fix(tester, 100);
    await tester.drag(find.byType(FlutterMap), const Offset(40, 90));
    await settle(tester);
    final LatLng before = camera(tester).center;
    final int listens = location.listens;
    expect(find.byKey(const ValueKey<String>('tiles.light')), findsOneWidget);

    mode.value = ThemeMode.dark;
    await settle(tester);
    await settle(tester);

    expect(find.byKey(const ValueKey<String>('tiles.dark')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tiles.light')), findsNothing);
    expect(camera(tester).center, before);
    expect(location.listens, listens, reason: 'GPS is not restarted');
    expect(recenter(), findsOneWidget, reason: 'follow state is kept');
    final List<Polyline> lines = tester
        .widgetList<PolylineLayer>(find.byType(PolylineLayer))
        .expand((PolylineLayer l) => l.polylines)
        .toList();
    expect(lines.single.points, hasLength(2));
    expect(lines.single.color, AppColors.dark.secondary);
    await finish(tester);
  });

  testWidgets('no tiles: a clear note, and the journey carries on', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    tiles.failure = const MapFailure(MapFailureCode.offline);
    await open(tester);
    await fix(tester, 0);
    await fix(tester, 100);
    expect(find.textContaining("can't load"), findsOneWidget);
    expect(find.textContaining("aren't affected"), findsOneWidget);
    expect(find.text('Recording'), findsOneWidget);
    expect(tracker.current?.distanceMeters, greaterThan(0));
    expect(find.byType(CurrentLocationDot), findsOneWidget);
    await finish(tester);
  });

  testWidgets('tiles failing later bring the note, tiles back remove it', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    expect(find.textContaining("can't load"), findsNothing);
    tiles.reachable.value = false;
    await tester.pump();
    expect(find.textContaining("can't load"), findsOneWidget);
    tiles.reachable.value = true;
    await tester.pump();
    expect(find.textContaining("can't load"), findsNothing);
    await finish(tester);
  });

  testWidgets('estimates show only with a route to base them on', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 100);
    expect(find.text('Remaining (estimate)'), findsNothing);
    expect(find.text('Arrival (estimate)'), findsNothing);
    await finish(tester);

    await boot(tester, 'en');
    routing.answer = const PlannedRoute(
      points: <LatLng>[LatLng(24.7, 46.67), LatLng(24.72, 46.67)],
      distanceMeters: 2200,
      durationSeconds: 300,
    );
    await open(tester);
    await fix(tester, 100);
    expect(find.text('Remaining (estimate)'), findsOneWidget);
    expect(find.text('Arrival (estimate)'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an unknown distance is not shown as zero', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'en');
    await tester.runAsync(() => journeys.complete(journey.id));
    await open(tester);
    expect(find.text('Journey ended'), findsOneWidget);
    expect(find.text('Travelled'), findsNothing);
    await finish(tester);
  });

  testWidgets('in Arabic: right to left, Arabic words and digits', (
    WidgetTester tester,
  ) async {
    await boot(tester, 'ar');
    await open(tester);
    await fix(tester, 0);
    await fix(tester, 100);
    expect(find.text('يجري التسجيل'), findsOneWidget);
    expect(find.text('السرعة'), findsOneWidget);
    expect(find.textContaining('٠٫١٠'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(JourneyMapPanel))),
      TextDirection.rtl,
    );
    await finish(tester);
  });

  testWidgets('controls and markers have names for a screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await boot(tester, 'en');
    await open(tester);
    await fix(tester, 0);
    expect(find.bySemanticsLabel('Zoom in'), findsOneWidget);
    expect(find.bySemanticsLabel('Zoom out'), findsOneWidget);
    expect(find.bySemanticsLabel('Follow my position'), findsOneWidget);
    expect(find.bySemanticsLabel('Your position'), findsOneWidget);
    semantics.dispose();
    await finish(tester);
  });

  for (final (String name, Size size, double scale) in <(String, Size, double)>[
    ('a small phone', const Size(960, 1600), 1),
    ('twice the text size', const Size(1170, 2532), 2),
    ('a tablet', const Size(2048, 2732), 1),
  ]) {
    testWidgets('$name: nothing overflows', (WidgetTester tester) async {
      await boot(tester, 'ar');
      await open(tester, size: size, textScale: scale);
      await fix(tester, 0);
      await fix(tester, 100);
      expect(tester.takeException(), isNull);
      expect(find.byType(JourneyMapPanel), findsOneWidget);
      await finish(tester);
    });
  }
}
