import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_asset_loader.dart';
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
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_start_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/checklist_item_tile.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/logic/cubit/open_escalation_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/incident_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/tracking_cubit.dart';
import '../tracking_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara', fullName: 'Sara');
}

final List<String> _items = JourneyChecklist.itemsOf(1);

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late FakeFirebaseFirestore db;
  late JourneyRepository journeys;
  late AppNotifier notices;

  Future<void> boot(String language) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    db = FakeFirebaseFirestore();
    journeys = FirestoreJourneyRepository(db, _Session());
    notices = AppNotifier();
    await sl.reset();
    registerSafetyNotes(_Session());
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<JourneysCubit>(
        () => JourneysCubit(journeys, _Session()),
      )
      ..registerFactory<JourneyCubit>(() => JourneyCubit(journeys))
      ..registerLazySingleton<JourneyTracker>(
        () => JourneyTracker(
          location: FakeLocation(),
          store: MemoryTrackStore(),
          route: FakeRoute(),
          journeys: journeys,
          session: _Session(),
        ),
        dispose: (JourneyTracker t) => t.dispose(),
      )
      ..registerFactory<TrackingCubit>(
        () => TrackingCubit(sl<JourneyTracker>()),
      )
      ..registerFactory<OpenEscalationCubit>(
        () => OpenEscalationCubit(NoEscalations()),
      )
      ..registerFactory<IncidentCubit>(
        () => IncidentCubit(MemoryIncidentRepository(), _Session()),
      )
      ..registerFactory<JourneyStartCubit>(() => JourneyStartCubit(journeys));
  }

  tearDown(sl.reset);

  Future<JourneyModel> seed(String to) => journeys.plan(
    origin: 'Home',
    destination: to,
    departsAt: DateTime.now().add(const Duration(hours: 2)),
  );

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
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
        assetLoader: const AppAssetLoader(),
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
    return router;
  }

  Finder text(String key) => find.text(key.tr());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    // Lay the scroll out before measuring where to tap.
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder tile(int i) => find.byType(ChecklistItemTile).at(i);

  List<bool> ticks(WidgetTester tester) => tester
      .widgetList<ChecklistItemTile>(find.byType(ChecklistItemTile))
      .map((ChecklistItemTile t) => t.confirmed)
      .toList();

  bool startEnabled(WidgetTester tester) =>
      tester
          .widget<AppPrimaryButton>(
            find.widgetWithText(
              AppPrimaryButton,
              'journeys.checklist.start'.tr(),
            ),
          )
          .onPressed !=
      null;

  String progress(int done) => 'journeys.checklist.progress'.tr(
    namedArgs: <String, String>{'done': '$done', 'total': '9'},
  );

  /// The journey's details, then its checklist through Start journey.
  Future<GoRouter> openChecklist(
    WidgetTester tester,
    JourneyModel journey, {
    ThemeMode theme = ThemeMode.light,
  }) async {
    final GoRouter router = await pumpApp(tester, theme: theme);
    router.pushNamed(
      AppRoutes.journey,
      pathParameters: <String, String>{'id': journey.id},
    );
    await tester.pumpAndSettle();
    await tap(tester, text('journeys.detail.start'));
    expect(router.state.name, AppRoutes.startJourney);
    return router;
  }

  /// Lets a notification's timer run out, so none outlives the test.
  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  testWidgets('every item starts unchecked; Start waits for all nine, then '
      'starts the journey with its checklist', (WidgetTester tester) async {
    await boot('en');
    final JourneyModel j = await seed('Work');
    final GoRouter router = await openChecklist(tester, j);

    expect(ticks(tester), List<bool>.filled(9, false));
    expect(find.text(progress(0)), findsOneWidget);
    expect(text('journeys.checklist.incomplete'), findsOneWidget);
    expect(startEnabled(tester), isFalse);
    for (final String item in _items) {
      expect(text('journeys.checklist.v1.$item'), findsOneWidget);
    }

    await tap(tester, tile(0));
    expect(ticks(tester).first, isTrue);
    expect(find.text(progress(1)), findsOneWidget);
    await tap(tester, tile(0));
    expect(ticks(tester).first, isFalse);
    expect(find.text(progress(0)), findsOneWidget);

    for (int i = 0; i < 8; i++) {
      await tap(tester, tile(i));
    }
    expect(find.text(progress(8)), findsOneWidget);
    expect(startEnabled(tester), isFalse);
    await tap(tester, tile(8));
    expect(find.text(progress(9)), findsOneWidget);
    expect(text('journeys.checklist.complete'), findsOneWidget);
    expect(startEnabled(tester), isTrue);

    await tap(tester, find.text('journeys.checklist.start'.tr()));
    expect(router.state.name, AppRoutes.journey);
    expect(notices.current?.title, 'journeys.notices.started.title'.tr());
    expect(notices.current?.message, 'journeys.notices.started.message'.tr());
    expect((await journeys.journey(j.id))?.status, JourneyStatus.active);
    final Map<String, dynamic> record =
        (await db
                .doc('users/sara/journeys/${j.id}/checklists/preJourney')
                .get())
            .data()!;
    expect(record['items'], _items);
    expect(record['version'], 1);

    // Started: complete or cancel, never start or edit again.
    expect(text('journeys.status.active'), findsOneWidget);
    expect(text('journeys.detail.complete'), findsOneWidget);
    expect(text('journeys.detail.start'), findsNothing);
    expect(text('journeys.detail.edit'), findsNothing);
    await outlast(tester);
  });

  testWidgets('Not now and back leave it planned; a return starts over', (
    WidgetTester tester,
  ) async {
    await boot('en');
    final JourneyModel j = await seed('Work');
    final GoRouter router = await openChecklist(tester, j);
    for (int i = 0; i < 9; i++) {
      await tap(tester, tile(i));
    }

    await tap(tester, find.text('journeys.checklist.notNow'.tr()));
    expect(router.state.name, AppRoutes.journey);
    expect(notices.current?.title, 'journeys.notices.notStarted'.tr());
    expect((await journeys.journey(j.id))?.status, JourneyStatus.planned);
    // The notice sits over the top of the screen; let it go first.
    await outlast(tester);

    await tap(tester, text('journeys.detail.start'));
    expect(ticks(tester), List<bool>.filled(9, false));
    await tap(tester, tile(2));
    expect(ticks(tester)[2], isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.journey);
    expect(notices.current?.title, 'journeys.notices.notStarted'.tr());
    expect((await journeys.journey(j.id))?.status, JourneyStatus.planned);
    expect(
      (await db.doc('users/sara/journeys/${j.id}/checklists/preJourney').get())
          .exists,
      isFalse,
    );
    await outlast(tester);
  });

  testWidgets('a new journey needs its own checklist', (
    WidgetTester tester,
  ) async {
    await boot('en');
    final JourneyModel first = await seed('Work');
    await journeys.start(
      first.id,
      checklistVersion: 1,
      confirmed: _items.toSet(),
    );
    final JourneyModel second = await seed('Gym');

    await openChecklist(tester, second);
    expect(ticks(tester), List<bool>.filled(9, false));
    expect(startEnabled(tester), isFalse);
  });

  testWidgets('a started or closed journey has no checklist to answer', (
    WidgetTester tester,
  ) async {
    await boot('en');
    final JourneyModel started = await seed('Work');
    await journeys.start(
      started.id,
      checklistVersion: 1,
      confirmed: _items.toSet(),
    );
    final JourneyModel closed = await seed('Gym');
    await journeys.cancel(closed.id);
    final GoRouter router = await pumpApp(tester);

    router.pushNamed(
      AppRoutes.startJourney,
      pathParameters: <String, String>{'id': started.id},
    );
    await tester.pumpAndSettle();
    expect(text('journeys.checklist.unavailable'), findsOneWidget);
    expect(text('journeys.errors.alreadyStarted'), findsOneWidget);
    expect(find.byType(ChecklistItemTile), findsNothing);

    router.pushNamed(
      AppRoutes.startJourney,
      pathParameters: <String, String>{'id': closed.id},
    );
    await tester.pumpAndSettle();
    expect(text('journeys.errors.notPlanned'), findsOneWidget);
    expect(find.byType(ChecklistItemTile), findsNothing);
  });

  testWidgets('in Arabic it reads right to left, in Arabic-Indic digits', (
    WidgetTester tester,
  ) async {
    await boot('ar');
    final JourneyModel j = await seed('العمل');
    await openChecklist(tester, j);

    final BuildContext first = tester.element(tile(0));
    expect(Directionality.of(first), TextDirection.rtl);
    expect(find.text('تم تأكيد ٠ من ٩'), findsOneWidget);
    // The box sits at the reading start: the right edge.
    final Rect box = tester.getRect(
      find.descendant(of: tile(0), matching: find.byType(Icon)),
    );
    final Rect label = tester.getRect(
      find.descendant(of: tile(0), matching: find.byType(Text)),
    );
    expect(box.center.dx, greaterThan(label.center.dx));

    await tap(tester, tile(0));
    expect(find.text('تم تأكيد ١ من ٩'), findsOneWidget);
  });

  for (final (ThemeMode mode, AppColors palette) in <(ThemeMode, AppColors)>[
    (ThemeMode.light, AppColors.light),
    (ThemeMode.dark, AppColors.dark),
  ]) {
    testWidgets('a confirmed item is drawn from the ${mode.name} palette', (
      WidgetTester tester,
    ) async {
      await boot('en');
      final JourneyModel j = await seed('Work');
      await openChecklist(tester, j, theme: mode);

      Color fill() => tester
          .widget<Material>(
            find.descendant(of: tile(0), matching: find.byType(Material)),
          )
          .color!;

      expect(fill(), palette.surface);
      await tap(tester, tile(0));
      expect(fill(), palette.tint(palette.primary));
    });
  }
}
