import 'dart:math';

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
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/router/app_router.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_connection_repository.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/accept_connection_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_form_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_reach_cubit.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_reach_buttons.dart';

import '../connection_fakes.dart';
import '../help_fakes.dart';

/// What a phone gets while `firestore.rules` is not deployed.
class _Refusing implements ConnectionRepository {
  const _Refusing();

  Never _refuse() =>
      throw const ConnectionFailure(ConnectionFailureCode.unavailable);

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  bool get mayBeStale => false;

  @override
  Future<List<ConnectionModel>> connections() async => _refuse();

  @override
  Future<List<ConnectionInviteModel>> invites() async => _refuse();

  @override
  Future<ConnectionInviteModel> createInvite() async => _refuse();

  @override
  Future<void> cancelInvite(String token) async => _refuse();

  @override
  Future<ConnectionInviteModel> preview(String token) async => _refuse();

  @override
  Future<ConnectionModel> accept(String token) async => _refuse();

  @override
  Future<void> revoke(String contactUid) async => _refuse();

  @override
  Future<void> rename(String contactUid, String? nickname) async => _refuse();

  @override
  Future<void> clear(String contactUid) async => _refuse();
}

/// The real router and screens over the Firestore repository, on
/// `fake_cloud_firestore`: Sara's phone, with Omar's account beside it.
void main() {
  EasyLocalization.logger.enableBuildModes = [];
  final String token = BearerToken.generate(Random(1));
  late FailingFirestore db;
  late FakeConnectionLinks links;
  late FakeConnectionSession session;
  late FirestoreConnectionRepository sara;
  late FirestoreConnectionRepository omar;
  late AppNotifier notices;

  Future<void> seedLocale(String locale) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': locale});
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
  }

  setUp(() async {
    await seedLocale('en');
    db = FailingFirestore();
    links = FakeConnectionLinks();
    session = FakeConnectionSession('sara');
    sara = FirestoreConnectionRepository(
      db,
      session,
      links,
      newToken: () => token,
    );
    omar = connectionsFor(db, 'omar', links: links);
    await db.doc('users/sara').set(<String, Object>{'fullName': 'Sara Ahmed'});
    await db.doc('users/omar').set(<String, Object>{'fullName': 'Omar Ali'});
    final TrustedContactsRepository contacts =
        FirestoreTrustedContactsRepository(db, session);
    notices = AppNotifier();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<ConnectionsCubit>(() => ConnectionsCubit(sara))
      ..registerFactory<AcceptConnectionCubit>(
        () => AcceptConnectionCubit(sara),
      )
      ..registerFactory<ContactsCubit>(() => ContactsCubit(contacts))
      ..registerFactory<ContactReachCubit>(
        () => ContactReachCubit(
          CallLauncher(RecordingDialer(), RecordingComposer()),
        ),
      )
      ..registerFactory<ContactFormCubit>(() => ContactFormCubit(contacts));
  });
  tearDown(sl.reset);

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    String start = AppRoutes.trustedContactsPath,
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final PreferencesCubit prefs = PreferencesCubit(
      AppPreferences(await SharedPreferences.getInstance()),
    );
    addTearDown(prefs.close);
    final GoRouter router = AppRouter.create(initialLocation: start);
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
              themeMode: mode,
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
    for (int i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
    }
    await tester.pumpAndSettle();
    return router;
  }

  Finder text(String key, {Map<String, String>? args}) =>
      find.text(key.tr(namedArgs: args));

  /// A future made under `runAsync` finishes on the real event loop, which a
  /// pumping test never yields to (CLAUDE.md §14).
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
    await tester.tap(finder.last);
    await settle(tester);
  }

  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  Future<void> connect(WidgetTester tester) => tester.runAsync(() async {
    await sara.createInvite();
    await omar.accept(token);
  });

  testWidgets('empty: it explains itself, and offers both ways in', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(text('safety.connections.heading'), findsOneWidget);
    expect(text('safety.connections.notice'), findsOneWidget);
    expect(text('safety.connections.empty.title'), findsOneWidget);
    expect(text('safety.connections.invite'), findsOneWidget);
    expect(text('safety.connections.haveInvite'), findsOneWidget);
    expect(text('safety.contacts.heading'), findsOneWidget);
    expect(text('safety.connections.invites.heading'), findsNothing);
  });

  testWidgets('an invite is made, and shows waiting with its link', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tap(tester, text('safety.connections.invite'));

    expect(text('safety.connections.invites.created.title'), findsOneWidget);
    expect(text('safety.connections.invites.heading'), findsOneWidget);
    expect(text('safety.connections.status.pending'), findsOneWidget);
    expect(text('safety.connections.invites.copy'), findsOneWidget);
    expect(text('safety.connections.invites.share'), findsOneWidget);
    expect(find.textContaining('Expires'), findsOneWidget);
    await outlast(tester);
  });

  testWidgets('offline, no invite appears, and it says nothing happened', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    db.transactionError = 'unavailable';
    await tap(tester, text('safety.connections.invite'));

    expect(text('safety.connections.errors.offline.title'), findsOneWidget);
    expect(text('safety.connections.invites.heading'), findsNothing);
    await outlast(tester);
  });

  testWidgets('a cancelled invite asks first, then goes', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(sara.createInvite);
    await pumpApp(tester);
    await tap(tester, text('safety.connections.invites.cancel'));
    expect(
      text('safety.connections.invites.cancelConfirm.body'),
      findsOneWidget,
    );

    await tap(tester, text('safety.connections.invites.cancelConfirm.keep'));
    expect(text('safety.connections.invites.heading'), findsOneWidget);

    await tap(tester, text('safety.connections.invites.cancel'));
    await tap(tester, text('safety.connections.invites.cancelConfirm.confirm'));
    expect(text('safety.connections.invites.heading'), findsNothing);
    await outlast(tester);
  });

  testWidgets('someone connected: name, status, date, what it opens', (
    WidgetTester tester,
  ) async {
    await connect(tester);
    await pumpApp(tester);

    expect(find.text('Omar Ali'), findsOneWidget);
    expect(text('safety.connections.status.accepted'), findsOneWidget);
    expect(find.textContaining('Connected '), findsWidgets);
    expect(text('safety.connections.nothingShared'), findsOneWidget);
    expect(text('safety.connections.manage'), findsOneWidget);
    expect(text('safety.connections.remove'), findsOneWidget);
    expect(text('safety.connections.empty.title'), findsNothing);
  });

  testWidgets('Batch 21: a connected person, then an ended one, has no Call '
      'or Message — a connection shares no phone number', (
    WidgetTester tester,
  ) async {
    await connect(tester);
    await pumpApp(tester);
    expect(find.text('Omar Ali'), findsOneWidget);
    expect(find.byType(ContactReachButtons), findsNothing);
    expect(
      find.textContaining('no phone number, no location and no journeys'),
      findsOneWidget,
    );

    await tap(tester, text('safety.connections.remove'));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: text('safety.connections.removeConfirm.confirm'),
      ),
    );
    await settle(tester);
    expect(text('safety.connections.ended.heading'), findsOneWidget);
    expect(find.byType(ContactReachButtons), findsNothing);
    await outlast(tester);
  });

  testWidgets('removing says what it cannot undo, and that links are apart', (
    WidgetTester tester,
  ) async {
    await connect(tester);
    await pumpApp(tester);
    await tap(tester, text('safety.connections.remove'));

    expect(
      text(
        'safety.connections.removeConfirm.title',
        args: <String, String>{'name': 'Omar Ali'},
      ),
      findsOneWidget,
    );
    final String body = 'safety.connections.removeConfirm.body'.tr();
    expect(body, contains("can't undo"));
    expect(body, contains('Sharing'));
    expect(find.text(body), findsOneWidget);

    await tap(tester, text('safety.connections.removeConfirm.keep'));
    expect(text('safety.connections.status.accepted'), findsOneWidget);

    await tap(tester, text('safety.connections.remove'));

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: text('safety.connections.removeConfirm.confirm'),
      ),
    );
    await settle(tester);

    expect(text('safety.connections.status.accepted'), findsNothing);
    expect(text('safety.connections.ended.heading'), findsOneWidget);
    await outlast(tester);
  });

  testWidgets('removing offline keeps them connected, and says so', (
    WidgetTester tester,
  ) async {
    await connect(tester);
    await pumpApp(tester);
    db.transactionError = 'unavailable';
    await tap(tester, text('safety.connections.remove'));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: text('safety.connections.removeConfirm.confirm'),
      ),
    );
    await settle(tester);

    expect(text('safety.connections.errors.offline.title'), findsOneWidget);
    expect(text('safety.connections.status.accepted'), findsOneWidget);
    await outlast(tester);
  });

  testWidgets('manage: nothing is a switch, and the nickname is saved', (
    WidgetTester tester,
  ) async {
    await connect(tester);
    await pumpApp(tester);
    await tap(tester, text('safety.connections.manage'));

    expect(
      text('safety.connections.access.liveLocation.title'),
      findsOneWidget,
    );
    expect(
      text('safety.connections.access.safetyAlerts.title'),
      findsOneWidget,
    );
    expect(text('safety.connections.manageScreen.separate'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Brother');
    await tap(tester, text('safety.connections.manageScreen.save'));
    expect(text('safety.connections.manageScreen.saved'), findsOneWidget);
    expect(find.text('Brother'), findsWidgets);
    await outlast(tester);
  });

  testWidgets('manage says so when the other person ended it', (
    WidgetTester tester,
  ) async {
    await connect(tester);
    await pumpApp(tester);
    await tap(tester, text('safety.connections.manage'));
    await tester.runAsync(() => omar.revoke('sara'));
    await settle(tester);
    expect(text('safety.connections.manageScreen.gone.title'), findsOneWidget);
  });

  testWidgets('the rules not being deployed reads as not available yet', (
    WidgetTester tester,
  ) async {
    sl
      ..unregister<ConnectionsCubit>()
      ..registerFactory<ConnectionsCubit>(
        () => ConnectionsCubit(const _Refusing()),
      );
    await pumpApp(tester);
    expect(text('safety.connections.errors.unavailable.title'), findsOneWidget);
    expect(text('safety.contacts.heading'), findsOneWidget);
  });

  group('answering an invite', () {
    String path() => '${AppRoutes.connectionInvitePath}#$token';

    Future<void> invited(WidgetTester tester) => tester.runAsync(
      connectionsFor(
        db,
        'omar',
        links: links,
        newToken: () => token,
      ).createInvite,
    );

    testWidgets('from the link: who it is, what it means, then a yes', (
      WidgetTester tester,
    ) async {
      await invited(tester);
      await pumpApp(tester, start: path());
      await settle(tester);

      expect(
        text(
          'safety.connections.accept.invited',
          args: <String, String>{'name': 'Omar Ali'},
        ),
        findsOneWidget,
      );
      expect(text('safety.connections.accept.meansNothing'), findsOneWidget);
      expect(text('safety.connections.accept.onlyIfKnown'), findsOneWidget);

      await tap(tester, text('safety.connections.accept.accept'));
      await settle(tester);

      expect(
        text(
          'safety.connections.accept.done.title',
          args: <String, String>{'name': 'Omar Ali'},
        ),
        findsOneWidget,
      );
      expect(text('safety.connections.status.accepted'), findsOneWidget);
      await outlast(tester);
    });

    testWidgets('offline: not connected, and the offer stays', (
      WidgetTester tester,
    ) async {
      await invited(tester);
      await pumpApp(tester, start: path());
      await settle(tester);
      db.transactionError = 'unavailable';
      await tap(tester, text('safety.connections.accept.accept'));

      expect(text('safety.connections.errors.offline.title'), findsOneWidget);
      expect(text('safety.connections.accept.accept'), findsOneWidget);
      await outlast(tester);
    });

    testWidgets('an invite that cannot be used says so', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, start: path());
      await settle(tester);
      expect(
        text('safety.connections.errors.noLongerValid.title'),
        findsOneWidget,
      );
      await tap(tester, text('safety.connections.accept.another'));
      expect(text('safety.connections.accept.linkLabel'), findsOneWidget);
    });

    testWidgets('signed out: sign in first, nothing is read', (
      WidgetTester tester,
    ) async {
      await invited(tester);
      session.id = null;
      await pumpApp(tester, start: path());
      await settle(tester);
      expect(text('safety.connections.accept.signedOut.title'), findsOneWidget);
    });

    testWidgets('one\'s own invite is told apart', (WidgetTester tester) async {
      await tester.runAsync(sara.createInvite);
      await pumpApp(tester, start: path());
      await settle(tester);
      expect(text('safety.connections.errors.ownInvite.title'), findsOneWidget);
    });

    testWidgets('pasted: anything that is not an invite says so', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, start: AppRoutes.connectionInvitePath);
      await tester.enterText(find.byType(TextFormField), 'hello');
      await tap(tester, text('safety.connections.accept.continue'));
      expect(text('safety.connections.errors.invalid.title'), findsOneWidget);
    });

    testWidgets('pasted: the whole message works', (WidgetTester tester) async {
      await invited(tester);
      await pumpApp(tester, start: AppRoutes.connectionInvitePath);
      await tester.enterText(
        find.byType(TextFormField),
        'Omar invited you: https://example.com/c#$token',
      );
      await tap(tester, text('safety.connections.accept.continue'));
      expect(text('safety.connections.accept.accept'), findsOneWidget);
    });
  });

  testWidgets('Arabic, dark: the screens read right to left', (
    WidgetTester tester,
  ) async {
    await seedLocale('ar');
    await connect(tester);
    await pumpApp(tester, mode: ThemeMode.dark);

    expect(find.text('الأشخاص المرتبطون بك'), findsOneWidget);
    expect(find.text('مرتبط'), findsOneWidget);
    expect(find.text('إدارة'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('إدارة'))).name, 'rtl');
    expect(tester.takeException(), isNull);

    await tap(tester, find.text('إزالة'));
    expect(find.textContaining('لا يمكنه التراجع'), findsOneWidget);
    await tap(tester, find.text('إبقاء'));

    await tap(tester, find.text('إدارة'));
    expect(find.text('الموقع المباشر: لا'), findsOneWidget);
    expect(find.text('تنبيهات السلامة: غير متاحة'), findsOneWidget);
  });
}
