import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/plan_journey_cubit.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_form_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_invite_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_links_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/country/country_fakes.dart';
import '../invite_fakes.dart';

/// Never opens anything: no test reaches a real dialer.
class _Dialer implements PhoneDialer {
  const _Dialer();

  @override
  Future<DialOutcome> open(String number) async => DialOutcome.opened;
}

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      const SessionUser(id: 'sara-uid', fullName: 'Sara Ahmed');
}

/// A contacts store whose reads fail while [broken] is set.
class _Unreadable extends Fake implements TrustedContactsRepository {
  bool broken = true;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<TrustedContactModel?> contact(String id) async {
    if (broken) throw const ContactFailure(ContactFailureCode.storage);
    return null;
  }
}

/// The real router and Safety screens over the Firestore contacts repository
/// (on `fake_cloud_firestore`).
void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late TrustedContactsRepository contacts;
  late AppNotifier notices;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'en'});
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    final FakeFirebaseFirestore db = FakeFirebaseFirestore();
    contacts = FirestoreTrustedContactsRepository(db, _Session());
    final JourneyRepository journeys = FirestoreJourneyRepository(
      db,
      _Session(),
    );
    notices = AppNotifier();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerSingleton<TrustedContactsRepository>(contacts)
      ..registerFactory<ContactsCubit>(() => ContactsCubit(contacts))
      ..registerFactory<ContactFormCubit>(() => ContactFormCubit(contacts))
      ..registerFactory<ContactLinksCubit>(
        () => ContactLinksCubit(FakeInvites()),
      )
      ..registerFactory<ContactInviteCubit>(
        () => ContactInviteCubit(FakeInvites()),
      )
      ..registerFactory<JourneysCubit>(
        () => JourneysCubit(journeys, _Session()),
      )
      ..registerFactory<PlanJourneyCubit>(() => PlanJourneyCubit(journeys))
      ..registerFactory<EmergencyCubit>(
        () => EmergencyCubit(
          MemoryCountryRepository('SA'),
          BundledEmergencyRepository(EmergencyDataSource()),
          const _Dialer(),
        ),
      );
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
      initialLocation: AppRoutes.safetyPath,
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

  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  testWidgets('the Safety Center leads to four working screens', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    expect(text('safety.title'), findsOneWidget);

    for (final (String key, String route) in <(String, String)>[
      ('contacts', AppRoutes.trustedContacts),
      ('guide', AppRoutes.safetyGuide),
      ('journeys', AppRoutes.journeySafety),
      ('emergency', AppRoutes.emergencyInfo),
    ]) {
      await tap(tester, text('safety.entries.$key.title'));
      expect(router.state.name, route);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('add, edit and delete a contact, with validation and asking', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(AppRoutes.trustedContacts);
    await tester.pumpAndSettle();
    expect(text('safety.contacts.empty.title'), findsOneWidget);
    expect(text('safety.contacts.notice'), findsOneWidget);

    await tap(tester, text('safety.contacts.add'));
    await tap(tester, text('safety.contacts.form.save'));
    expect(await contacts.contacts(), isEmpty);
    expect(text('validation.required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Lina Saad');
    await tester.enterText(find.byType(TextFormField).at(1), '0550001111');
    await tester.enterText(find.byType(TextFormField).at(2), 'Sister');
    await tap(tester, text('safety.contacts.form.save'));

    expect(router.state.name, AppRoutes.trustedContacts);
    expect(find.text('Lina Saad'), findsOneWidget);
    expect(find.textContaining('Sister'), findsOneWidget);
    expect(notices.current?.title, 'safety.contacts.notices.added'.tr());
    await outlast(tester);

    await tap(tester, find.text('Lina Saad'));
    expect(router.state.name, AppRoutes.editContact);
    expect(find.widgetWithText(TextFormField, 'Lina Saad'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Lina S.');
    await tap(tester, text('safety.contacts.form.save'));
    expect(find.text('Lina S.'), findsOneWidget);
    await outlast(tester);

    await tap(tester, find.text('Lina S.'));
    await tap(tester, text('safety.contacts.form.delete'));
    expect(text('safety.contacts.confirmDelete.title'), findsOneWidget);
    await tap(tester, text('safety.contacts.confirmDelete.confirm'));
    expect(await contacts.contacts(), isEmpty);
    expect(text('safety.contacts.empty.title'), findsOneWidget);
    await outlast(tester);
  });

  testWidgets('a number already saved shows under the phone field', (
    WidgetTester tester,
  ) async {
    await contacts.add(fullName: 'Omar', phone: '0501234567');
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(AppRoutes.addContact);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Someone');
    await tester.enterText(find.byType(TextFormField).at(1), '050 123 4567');
    await tap(tester, text('safety.contacts.form.save'));

    expect(router.state.name, AppRoutes.addContact);
    expect(text('safety.contacts.errors.duplicatePhone'), findsOneWidget);
    expect(find.text('Someone'), findsOneWidget);
    final List<TrustedContactModel> saved = await contacts.contacts();
    expect(saved, hasLength(1));
  });

  testWidgets('a missing contact says so', (WidgetTester tester) async {
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.editContact,
      pathParameters: <String, String>{'id': 'gone'},
    );
    await tester.pumpAndSettle();
    expect(text('safety.contacts.errors.notFound'), findsOneWidget);
    expect(text('safety.contacts.form.save'), findsNothing);
  });

  // An empty form here would save a second contact; the screen offers a
  // retry instead, and the retry reads again.
  testWidgets('a contact that cannot be read offers a retry, not a form', (
    WidgetTester tester,
  ) async {
    final _Unreadable store = _Unreadable();
    sl
      ..unregister<ContactFormCubit>()
      ..registerFactory<ContactFormCubit>(() => ContactFormCubit(store));
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(
      AppRoutes.editContact,
      pathParameters: <String, String>{'id': 'c1'},
    );
    await tester.pumpAndSettle();
    expect(text('safety.contacts.form.unreadable.title'), findsOneWidget);
    expect(text('safety.contacts.form.save'), findsNothing);
    expect(text('safety.contacts.form.delete'), findsNothing);
    expect(notices.current, isNull);

    store.broken = false;
    await tester.tap(text('safety.contacts.failed.retry'));
    await tester.pumpAndSettle();
    expect(text('safety.contacts.errors.notFound'), findsOneWidget);
  });

  testWidgets('the guide and emergency numbers are there, with sources', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    router.pushNamed(AppRoutes.safetyGuide);
    await tester.pumpAndSettle();
    for (final String s in <String>['before', 'during', 'after', 'emergency']) {
      await tester.scrollUntilVisible(
        text('safety.guide.sections.$s.title'),
        200,
      );
      expect(text('safety.guide.sections.$s.title'), findsOneWidget);
    }

    router.pop();
    await tester.pumpAndSettle();
    router.pushNamed(AppRoutes.emergencyInfo);
    await tester.pumpAndSettle();
    for (final String n in <String>['911', '999', '997', '998']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(text('safety.emergency.call'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('National Numbering Plan'),
      200,
    );
    expect(find.textContaining('National Numbering Plan'), findsOneWidget);
  });

  testWidgets('with no alert backend, nothing offers alerts or invites', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester);
    router.goNamed(AppRoutes.safety);
    await tester.pumpAndSettle();
    expect(text('safety.entries.alerts.title'), findsNothing);
    expect(text('safety.entries.invite.title'), findsNothing);
    expect(find.textContaining("doesn't alert your contacts"), findsOneWidget);

    await contacts.add(fullName: 'Mona Saleh', phone: '+966551112222');
    router.pushNamed(AppRoutes.trustedContacts);
    await tester.pumpAndSettle();
    expect(find.text('Mona Saleh'), findsOneWidget);
    expect(text('safety.contacts.alertsOff'), findsNothing);
    expect(find.textContaining('send them anything'), findsOneWidget);
    await tester.tap(find.text('Mona Saleh'));
    await tester.pumpAndSettle();
    expect(text('safety.invite.create'), findsNothing);
  });
}
