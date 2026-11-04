import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/router/app_router.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/incident_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/tracking_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/incident_banner.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late JourneyRepository journeys;
  late AppNotifier notices;
  late FakeLocation location;
  late MemoryTrackStore store;
  late JourneyTracker tracker;
  late MemoryIncidentRepository incidents;

  Future<void> boot(String language, LocationAccess access) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    journeys = FirestoreJourneyRepository(FakeFirebaseFirestore(), _Session());
    notices = AppNotifier();
    location = FakeLocation(now: access, afterAsking: LocationAccess.granted);
    store = MemoryTrackStore();
    incidents = MemoryIncidentRepository();
    tracker = JourneyTracker(
      location: location,
      store: store,
      route: FakeRoute(),
      journeys: journeys,
      session: _Session(),
    );
    await sl.reset();
    registerSafetyNotes(_Session());
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<JourneysCubit>(
        () => JourneysCubit(journeys, _Session()),
      )
      ..registerFactory<JourneyCubit>(() => JourneyCubit(journeys))
      ..registerFactory<TrackingCubit>(() => TrackingCubit(tracker))
      ..registerFactory<IncidentCubit>(
        () => IncidentCubit(incidents, _Session()),
      );
  }

  tearDown(sl.reset);

  Future<JourneyModel> started() async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await journeys.start(
      j.id,
      checklistVersion: 1,
      confirmed: JourneyChecklist.itemsOf(1).toSet(),
    );
    return j;
  }

  Future<void> open(
    WidgetTester tester,
    JourneyModel journey, {
    ThemeMode theme = ThemeMode.light,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final PreferencesCubit prefs = PreferencesCubit(
      AppPreferences(await SharedPreferences.getInstance()),
    );
    addTearDown(prefs.close);
    final GoRouter router = AppRouter.create(
      initialLocation: AppRoutes.homePath,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        child: BlocProvider<PreferencesCubit>.value(
          value: prefs,
          child: ScreenUtilInit(
            designSize: const Size(AppDesign.width, AppDesign.height),
            builder: (BuildContext context, _) => MaterialApp.router(
              theme: ThemeData(
                extensions: const <ThemeExtension<dynamic>>[AppColors.light],
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
              ),
              themeMode: theme,
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
    router.pushNamed(
      AppRoutes.journey,
      pathParameters: <String, String>{'id': journey.id},
    );
    await tester.pumpAndSettle();
  }

  /// Stops the recording and its timers before the test ends.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Cancelling the Firestore listener completes on the real event loop.
    await tester.runAsync(tracker.dispose);
  }

  Finder text(String key) => find.text(key.tr());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('it explains, and asks for location only on a tap', (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.denied);
    final JourneyModel j = await started();
    await open(tester, j);

    expect(text('journeys.tracking.title'), findsOneWidget);
    expect(text('journeys.tracking.needs.denied.title'), findsOneWidget);
    expect(text('journeys.tracking.needs.denied.body'), findsOneWidget);
    expect(location.asked, 0);
    expect(location.listens, 0);

    await tap(tester, text('journeys.tracking.needs.denied.action'));
    expect(location.asked, 1);
    expect(location.noticesAsked, 1);
    expect(location.listens, 1);
    expect(text('journeys.tracking.status.starting'), findsOneWidget);
    expect(text('journeys.tracking.waiting'), findsOneWidget);

    location.fix(24.7, 46.67, speed: 10);
    await tester.pumpAndSettle();
    expect(text('journeys.tracking.status.active'), findsOneWidget);
    expect(find.text('36 km/h'), findsOneWidget);
    expect(text('journeys.tracking.speedCurrent'), findsOneWidget);
    expect(find.text('0.00 km'), findsOneWidget);
    expect(find.text('24.70000, 46.67000'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('refused for good: the settings, never the prompt', (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.deniedForever);
    await open(tester, await started());
    expect(text('journeys.tracking.needs.deniedForever.title'), findsOneWidget);
    await tap(tester, text('journeys.tracking.needs.deniedForever.action'));
    expect(location.opened, <String>['app']);
    expect(location.asked, 0);
    expect(location.noticesAsked, 0);

    // Allowed in the settings, then back to the app: it records.
    location.now = LocationAccess.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(text('journeys.tracking.status.starting'), findsOneWidget);
    await finish(tester);
  });

  testWidgets("the phone's location off: its location settings", (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.serviceOff);
    await open(tester, await started());
    await tap(tester, text('journeys.tracking.needs.serviceOff.action'));
    expect(location.opened, <String>['location']);
    await finish(tester);
  });

  testWidgets('approximate location only: asks for precise in settings', (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.approximate);
    await open(tester, await started());
    expect(text('journeys.tracking.needs.approximate.title'), findsOneWidget);
    await tap(tester, text('journeys.tracking.needs.approximate.action'));
    expect(location.opened, <String>['app']);
    await finish(tester);
  });

  testWidgets('in Arabic: right to left, Arabic-Indic digits', (
    WidgetTester tester,
  ) async {
    await boot('ar', LocationAccess.granted);
    await open(tester, await started());
    location.fix(24.7, 46.67, speed: 10);
    await tester.pumpAndSettle();

    expect(find.text('٣٦ كم/س'), findsOneWidget);
    expect(find.text('٠٫٠٠ كم'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(TrackingCard))),
      TextDirection.rtl,
    );
    // The title sits at the reading start: the right.
    final Rect card = tester.getRect(find.byType(TrackingCard));
    final Rect title = tester.getRect(text('journeys.tracking.title'));
    expect(title.right, greaterThan(card.center.dx));
    await finish(tester);
  });

  for (final (ThemeMode mode, AppColors palette) in <(ThemeMode, AppColors)>[
    (ThemeMode.light, AppColors.light),
    (ThemeMode.dark, AppColors.dark),
  ]) {
    testWidgets('the card is drawn from the ${mode.name} palette', (
      WidgetTester tester,
    ) async {
      await boot('en', LocationAccess.denied);
      await open(tester, await started(), theme: mode);
      final BoxDecoration box =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(TrackingCard),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(box.color, palette.surface);
      await finish(tester);
    });
  }

  testWidgets('an ended journey shows what was recorded', (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.granted);
    final JourneyModel done = await started();
    await journeys.complete(done.id);
    await store.saveSession(
      TrackSession(
        journeyId: done.id,
        uid: 'sara',
        recording: false,
        startedAt: DateTime.now().toUtc(),
        distanceMeters: 1234,
        pointCount: 5,
      ),
    );
    await open(tester, done);
    expect(text('journeys.tracking.status.stopped'), findsOneWidget);
    expect(find.text('Recorded distance: 1.23 km'), findsOneWidget);
    expect(location.listens, 0);
    await finish(tester);
  });

  testWidgets('completing while recording stops it and shows the result', (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.granted);
    await open(tester, await started());
    final DateTime now = DateTime.now().toUtc();
    location.fix(24.7, 46.67, at: now.subtract(const Duration(seconds: 10)));
    await tester.pumpAndSettle();
    location.fix(24.701, 46.67, at: now);
    await tester.pumpAndSettle();
    expect(text('journeys.tracking.status.active'), findsOneWidget);

    await tap(tester, text('journeys.detail.complete'));
    await tap(tester, text('journeys.confirmComplete.confirm').last);
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
    // The journeys' live query reaches the tracker on the real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(tracker.journeyId, isNull);
    expect(text('journeys.tracking.status.stopped'), findsOneWidget);
    expect(find.text('Recorded distance: 0.11 km'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a planned journey shows no recording', (
    WidgetTester tester,
  ) async {
    await boot('en', LocationAccess.granted);
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await open(tester, j);
    expect(find.byType(TrackingCard), findsNothing);
    expect(location.listens, 0);
    await finish(tester);
  });

  group('a potential incident', () {
    PotentialIncident event(
      JourneyModel j, {
      IncidentType type = IncidentType.suddenDeceleration,
      IncidentConfidence confidence = IncidentConfidence.medium,
      IncidentStatus status = IncidentStatus.detected,
    }) => PotentialIncident(
      id: '${j.id}-${type.name}',
      journeyId: j.id,
      uid: 'sara',
      type: type,
      status: status,
      confidence: confidence,
      detectedAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      reason: 'test',
      durationSeconds: 420,
    );

    testWidgets('is a calm note, never "an accident"; dismissed when fine', (
      WidgetTester tester,
    ) async {
      await boot('en', LocationAccess.denied);
      final JourneyModel j = await started();
      await incidents.put(event(j));
      await open(tester, j);

      expect(find.byType(IncidentBanner), findsOneWidget);
      expect(text('journeys.incident.title'), findsOneWidget);
      expect(text('journeys.incident.suddenDeceleration'), findsOneWidget);
      expect(text('journeys.incident.note'), findsOneWidget);
      expect(find.textContaining('accident'), findsOneWidget);
      expect(find.textContaining("isn't a confirmed accident"), findsOneWidget);

      await tap(tester, text('journeys.incident.dismiss'));
      expect(incidents.all.single.status, IncidentStatus.dismissed);
      expect(
        incidents.all.single.resolution,
        IncidentResolution.dismissedByUser,
      );
      expect(find.byType(IncidentBanner), findsNothing);
      await finish(tester);
    });

    testWidgets('low confidence, interruptions and closed events stay quiet', (
      WidgetTester tester,
    ) async {
      await boot('en', LocationAccess.denied);
      final JourneyModel j = await started();
      await incidents.put(event(j, confidence: IncidentConfidence.low));
      await incidents.put(event(j, type: IncidentType.trackingInterrupted));
      await incidents.put(
        event(
          j,
          type: IncidentType.prolongedStop,
          status: IncidentStatus.resolved,
        ),
      );
      await open(tester, j);
      expect(find.byType(IncidentBanner), findsNothing);
      await finish(tester);
    });

    testWidgets('an ended journey shows none', (WidgetTester tester) async {
      await boot('en', LocationAccess.granted);
      final JourneyModel j = await started();
      await incidents.put(event(j));
      await journeys.complete(j.id);
      await open(tester, j);
      expect(find.byType(IncidentBanner), findsNothing);
      await finish(tester);
    });

    testWidgets('in Arabic: right to left, minutes in Arabic-Indic digits', (
      WidgetTester tester,
    ) async {
      await boot('ar', LocationAccess.denied);
      final JourneyModel j = await started();
      await incidents.put(event(j, type: IncidentType.prolongedStop));
      await open(tester, j);
      expect(find.text('لاحظ SafeRide حركة غير معتادة'), findsOneWidget);
      expect(find.textContaining('٧ د'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(IncidentBanner))),
        TextDirection.rtl,
      );
      await finish(tester);
    });

    for (final (ThemeMode mode, AppColors palette) in <(ThemeMode, AppColors)>[
      (ThemeMode.light, AppColors.light),
      (ThemeMode.dark, AppColors.dark),
    ]) {
      testWidgets('drawn on the ${mode.name} info colour, not an alarm', (
        WidgetTester tester,
      ) async {
        await boot('en', LocationAccess.denied);
        final JourneyModel j = await started();
        await incidents.put(event(j));
        await open(tester, j, theme: mode);
        final BoxDecoration box =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(IncidentBanner),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(box.color, palette.tint(palette.info));
        await finish(tester);
      });
    }
  });
}
