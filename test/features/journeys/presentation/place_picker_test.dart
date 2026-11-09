import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/constants/app_asset_loader.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_picker_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_search_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/pages/place_picker_page.dart';
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

const JourneyPlace _mall = JourneyPlace(
  name: 'Dubai Mall',
  lat: 25.19,
  lng: 55.27,
  address: 'Dubai',
);

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late FakeGeocoding geo;
  late FakeLocation location;
  late JourneyTracker tracker;
  late Object? returned;

  Future<void> open(WidgetTester tester, {String language = 'en'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    geo = FakeGeocoding();
    location = FakeLocation(now: LocationAccess.granted);
    final _Session session = _Session();
    tracker = JourneyTracker(
      location: location,
      store: MemoryTrackStore(),
      route: FakeRoute(),
      journeys: FirestoreJourneyRepository(FakeFirebaseFirestore(), session),
      session: session,
      translate: (String k) => k,
    );
    returned = null;
    await sl.reset();
    sl
      ..registerSingleton<MapTileProvider>(FakeMapTiles())
      ..registerFactory<PlaceSearchCubit>(
        () => PlaceSearchCubit(geo, debounce: Duration.zero),
      )
      ..registerFactory<PlacePickerCubit>(
        () => PlacePickerCubit(geo, tracker, settle: Duration.zero),
      );
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, _) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  returned = await context.push<JourneyPlace>('/pick'),
              child: const Text('go'),
            ),
          ),
        ),
        GoRoute(
          path: '/pick',
          builder: (_, _) =>
              const PlacePickerPage(kind: MapPlaceKind.destination),
        ),
      ],
    );
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        assetLoader: const AppAssetLoader(),
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
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  tearDown(sl.reset);

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(tracker.dispose);
  }

  Future<void> rest(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await rest(tester);
    await rest(tester);
  }

  Finder confirm() => find.text('journeys.map.confirm'.tr());

  testWidgets('search, pick, confirm: the place comes back', (
    WidgetTester tester,
  ) async {
    await open(tester);
    geo.results = <JourneyPlace>[_mall];
    await search(tester, 'Dubai');
    expect(find.textContaining('Dubai Mall'), findsOneWidget);

    await tester.tap(find.textContaining('Dubai Mall'));
    await rest(tester);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(returned, _mall);
    await finish(tester);
  });

  testWidgets('nothing chosen yet: Confirm waits', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(confirm(), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(PlacePickerPage), findsOneWidget);
    expect(find.byType(PlacePin), findsNothing);
    await finish(tester);
  });

  testWidgets('tapping the map drops the pin there', (
    WidgetTester tester,
  ) async {
    await open(tester);
    geo.named = const JourneyPlace(name: 'Olaya', lat: 1, lng: 1);
    await tester.tapAt(const Offset(195, 400));
    await tester.pump(const Duration(milliseconds: 400));
    await rest(tester);
    expect(find.byType(PlacePin), findsOneWidget);
    expect(find.textContaining('Olaya'), findsOneWidget);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    final JourneyPlace back = returned! as JourneyPlace;
    expect(back.name, 'Olaya');
    expect(back.lat, isNot(1), reason: 'the pin, not the provider\'s match');
    await finish(tester);
  });

  testWidgets('dragging the map moves the pin', (WidgetTester tester) async {
    await open(tester);
    geo.named = const JourneyPlace(name: 'Olaya', lat: 1, lng: 1);
    await tester.drag(find.byType(FlutterMap), const Offset(30, 60));
    await tester.pump(const Duration(milliseconds: 500));
    await rest(tester);
    expect(find.byType(PlacePin), findsOneWidget);
    expect(geo.reverses, greaterThan(0));
    await finish(tester);
  });

  testWidgets('"Use my location" fills the pin with one reading', (
    WidgetTester tester,
  ) async {
    await open(tester);
    location.oneOff = LocationFix(
      latitude: 24.7,
      longitude: 46.7,
      at: DateTime.now().toUtc(),
      accuracy: 8,
    );
    await tester.tap(find.text('journeys.map.useLocation'.tr()));
    await rest(tester);
    await rest(tester);
    expect(find.byType(PlacePin), findsOneWidget);
    expect(location.listens, 0);
    await finish(tester);
  });

  testWidgets('search empty, offline and clear each say what happened', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await search(tester, 'zzzz');
    expect(find.text('journeys.map.search.empty'.tr()), findsOneWidget);

    geo.failure = const MapFailure(MapFailureCode.offline);
    await search(tester, 'yyyy');
    expect(find.text('journeys.map.search.offline'.tr()), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await rest(tester);
    expect(find.text('journeys.map.search.offline'.tr()), findsNothing);
    await finish(tester);
  });

  testWidgets('offline, a pin can still be confirmed, with a plain name', (
    WidgetTester tester,
  ) async {
    await open(tester);
    geo.failure = const MapFailure(MapFailureCode.offline);
    await tester.tapAt(const Offset(195, 400));
    await tester.pump(const Duration(milliseconds: 400));
    await rest(tester);
    expect(find.text('journeys.map.pinned'.tr()), findsOneWidget);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect((returned! as JourneyPlace).name, 'journeys.map.pinned'.tr());
    await finish(tester);
  });

  testWidgets('in Arabic', (WidgetTester tester) async {
    await open(tester, language: 'ar');
    expect(find.text('تأكيد هذا المكان'), findsOneWidget);
    expect(find.text('استخدام موقعي'), findsOneWidget);
    await finish(tester);
  });

  test('coordinates in a picked place are real numbers', () {
    expect(_mall.point, const LatLng(25.19, 55.27));
  });
}
