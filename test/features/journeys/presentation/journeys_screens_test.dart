import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/local_journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/plan_journey_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_tile_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara@example.com', fullName: 'Sara Ahmed');
}

class _Auth extends Fake implements AuthRepository {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<UserModel?> currentUser() async => UserModel(
    fullName: 'Sara Ahmed',
    email: 'sara@example.com',
    createdAt: DateTime.utc(2026),
  );
}

/// The real router, tab shell, pages and local journey repository (over the
/// secure-storage mock), signed in as Sara.
void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late JourneyRepository journeys;
  late AppNotifier notices;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    journeys = LocalJourneyRepository(const FlutterSecureStorage(), _Session());
    notices = AppNotifier();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerSingleton<JourneyRepository>(journeys)
      ..registerFactory<JourneysCubit>(
        () => JourneysCubit(journeys, _Session()),
      )
      ..registerFactory<PlanJourneyCubit>(() => PlanJourneyCubit(journeys))
      ..registerFactory<JourneyCubit>(() => JourneyCubit(journeys))
      ..registerFactory<AccountCubit>(() => AccountCubit(_Auth()));
  });
  tearDown(sl.reset);

  Future<GoRouter> pumpApp(WidgetTester tester) async {
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
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  /// Lets a notification's timer run out, so none outlives the test.
  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  testWidgets('home greets Sara, has no journeys, and plans nothing fake', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.textContaining('Sara'), findsOneWidget);
    expect(find.textContaining('Ahmed'), findsNothing);
    expect(text('home.recent.emptyTitle'), findsOneWidget);
    expect(text('home.recent.seeAll'), findsNothing);
    // Journey Sharing is planned and not tappable; the two built features
    // are links.
    expect(text('home.safety.planned'), findsOneWidget);
    Finder tappable(String key) => find.ancestor(
      of: text('home.safety.$key.title'),
      matching: find.byType(InkWell),
    );
    expect(tappable('sharing'), findsNothing);
    expect(tappable('contacts'), findsOneWidget);
    expect(tappable('resources'), findsOneWidget);
  });

  testWidgets('plan, review, confirm: details, then recent and My Journeys', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    await tap(tester, text('home.plan.action'));
    expect(router.state.name, AppRoutes.planJourney);

    await tester.enterText(find.byType(TextFormField).at(0), 'Home');
    await tester.enterText(find.byType(TextFormField).at(1), ' home ');
    await tap(tester, text('journeys.plan.review'));
    expect(text('validation.samePlace'), findsOneWidget);
    expect(router.state.name, AppRoutes.planJourney);

    await tester.enterText(find.byType(TextFormField).at(1), 'King Fahd Road');
    await tap(tester, text('journeys.plan.review'));
    expect(router.state.name, AppRoutes.reviewJourney);
    expect(
      await journeys.journeys(),
      isEmpty,
      reason: 'nothing before confirm',
    );

    await tap(tester, text('journeys.review.confirm'));
    expect(router.state.name, AppRoutes.journey);
    expect(text('journeys.status.planned'), findsOneWidget);
    expect(notices.current?.title, 'journeys.notices.planned.title'.tr());
    expect((await journeys.journeys()).single.destination, 'King Fahd Road');
    // The notice sits over the top of the screen; let it go before tapping
    // what scrolls up under it.
    await outlast(tester);

    // Plan and review are gone: back is home, now with the journey.
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.name, AppRoutes.home);
    expect(find.textContaining('King Fahd Road'), findsOneWidget);

    await tap(tester, text('home.recent.seeAll'));
    expect(router.state.name, AppRoutes.myJourneys);
    expect(find.textContaining('King Fahd Road'), findsOneWidget);
  });

  testWidgets('Cancel on review discards the plan', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    await tap(tester, text('home.plan.action'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Home');
    await tester.enterText(find.byType(TextFormField).at(1), 'Work');
    await tap(tester, text('journeys.plan.review'));

    await tap(tester, text('journeys.review.discard'));
    expect(router.state.name, AppRoutes.home);
    expect(await journeys.journeys(), isEmpty);
  });

  testWidgets('completing asks first, then closes the journey for good', (
    WidgetTester tester,
  ) async {
    final JourneyModel planned = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 2)),
    );
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.journey,
      pathParameters: <String, String>{'id': planned.id},
    );
    await tester.pumpAndSettle();

    await tap(tester, text('journeys.detail.complete'));
    expect(text('journeys.confirmComplete.message'), findsOneWidget);
    await tap(tester, text('journeys.confirmComplete.cancel'));
    expect((await journeys.journey(planned.id))!.status, JourneyStatus.planned);

    await tap(tester, text('journeys.detail.complete'));
    await tap(tester, text('journeys.confirmComplete.confirm'));
    expect(
      (await journeys.journey(planned.id))!.status,
      JourneyStatus.completed,
    );
    expect(text('journeys.status.completed'), findsOneWidget);
    expect(text('journeys.detail.complete'), findsNothing);
    expect(text('journeys.detail.settled'), findsOneWidget);
    expect(notices.current?.title, 'journeys.notices.completed'.tr());
    await outlast(tester);
  });

  testWidgets('a missing journey says so', (WidgetTester tester) async {
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.journey,
      pathParameters: <String, String>{'id': 'gone'},
    );
    await tester.pumpAndSettle();
    expect(text('journeys.detail.missingTitle'), findsOneWidget);
  });

  testWidgets('the avatar and the tab bar reach Profile and back', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final GoRouter router = await pumpApp(tester);
    await tap(tester, find.bySemanticsLabel('home.avatarLabel'.tr()));
    expect(router.state.name, AppRoutes.profile);
    expect(text('profile.signOut'), findsOneWidget);

    await tap(tester, text('tabs.journeys'));
    expect(router.state.name, AppRoutes.myJourneys);
    expect(text('journeys.empty.title'), findsOneWidget);

    await tap(tester, text('tabs.home'));
    expect(router.state.name, AppRoutes.home);
    semantics.dispose();
  });

  Future<JourneyModel> seed(String to, {bool cancel = false}) async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: to,
      departsAt: DateTime.now().add(const Duration(hours: 3)),
    );
    if (cancel) await journeys.cancel(j.id);
    return j;
  }

  Finder chip(String key) => find.widgetWithText(ChoiceChip, key.tr());

  testWidgets('My Journeys filters by status and says when none match', (
    WidgetTester tester,
  ) async {
    await seed('Work');
    await seed('Gym', cancel: true);
    final GoRouter router = await pumpApp(tester);
    router.goNamed(AppRoutes.myJourneys);
    await tester.pumpAndSettle();

    expect(find.textContaining('Work'), findsOneWidget);
    expect(find.textContaining('Gym'), findsOneWidget);

    await tap(tester, chip('journeys.filter.cancelled'));
    expect(find.textContaining('Work'), findsNothing);
    expect(find.textContaining('Gym'), findsOneWidget);

    await tap(tester, chip('journeys.filter.completed'));
    expect(text('journeys.filter.empty.completed'), findsOneWidget);

    await tap(tester, chip('journeys.filter.all'));
    expect(find.textContaining('Work'), findsOneWidget);
  });

  testWidgets(
    'a planned journey can be cancelled from the list, after asking',
    (WidgetTester tester) async {
      final JourneyModel j = await seed('Work');
      final GoRouter router = await pumpApp(tester);
      router.goNamed(AppRoutes.myJourneys);
      await tester.pumpAndSettle();

      // Only a planned journey has the menu.
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      await tap(tester, find.byIcon(Icons.more_vert_rounded));
      await tap(tester, text('journeys.detail.cancel'));
      expect(text('journeys.confirmCancel.message'), findsOneWidget);
      await tap(tester, text('journeys.confirmCancel.confirm'));

      expect((await journeys.journey(j.id))!.status, JourneyStatus.cancelled);
      expect(
        find.descendant(
          of: find.byType(JourneyTileBody),
          matching: text('journeys.status.cancelled'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      expect(notices.current?.title, 'journeys.notices.cancelled'.tr());
      await outlast(tester);
    },
  );

  testWidgets('editing a planned journey saves and shows on its details', (
    WidgetTester tester,
  ) async {
    final JourneyModel j = await seed('Work');
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.journey,
      pathParameters: <String, String>{'id': j.id},
    );
    await tester.pumpAndSettle();
    expect(text('journeys.departure'), findsOneWidget);

    await tap(tester, text('journeys.detail.edit'));
    expect(router.state.name, AppRoutes.editJourney);
    expect(find.widgetWithText(TextFormField, 'Work'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'Airport');
    await tap(tester, text('journeys.edit.save'));

    expect(router.state.name, AppRoutes.journey);
    expect(find.textContaining('Airport'), findsOneWidget);
    expect((await journeys.journey(j.id))!.destination, 'Airport');
    expect(notices.current?.title, 'journeys.notices.updated'.tr());
    await outlast(tester);
  });

  // A planned journey whose time has gone by can still have a place fixed;
  // only a newly picked departure must be in the future.
  testWidgets('an overdue journey keeps its departure through an edit', (
    WidgetTester tester,
  ) async {
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: 'Wrok',
      departsAt: yesterday,
    );
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.editJourney,
      pathParameters: <String, String>{'id': j.id},
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Work');
    await tap(tester, text('journeys.edit.save'));

    expect(text('validation.departurePast'), findsNothing);
    final JourneyModel saved = (await journeys.journey(j.id))!;
    expect(saved.destination, 'Work');
    expect(saved.departsAt, j.departsAt);
    await outlast(tester);
  });

  testWidgets('a closed journey offers no edit, and its edit screen says so', (
    WidgetTester tester,
  ) async {
    final JourneyModel j = await seed('Gym', cancel: true);
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.journey,
      pathParameters: <String, String>{'id': j.id},
    );
    await tester.pumpAndSettle();
    expect(text('journeys.detail.edit'), findsNothing);

    router.pushNamed(
      AppRoutes.editJourney,
      pathParameters: <String, String>{'id': j.id},
    );
    await tester.pumpAndSettle();
    expect(text('journeys.detail.settled'), findsOneWidget);
    expect(text('journeys.edit.save'), findsNothing);
  });
}
