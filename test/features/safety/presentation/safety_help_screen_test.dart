import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/safety_help_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';
import 'package:safe_ride/features/safety/presentation/widgets/help_person.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_reach_buttons.dart';

import '../../../core/safety/position_fakes.dart';
import '../../../core/country/country_fakes.dart';
import '../help_fakes.dart';

/// The help screen through the real router: what it shows, what Call does,
/// and what it never claims. The dialer is a fake: nothing is ever dialled.
void main() {
  EasyLocalization.logger.enableBuildModes = [];
  final DateTime at = DateTime.utc(2026, 11, 8, 9);
  late FakeGate gate;
  late FakeConnections connections;
  late FakeContacts contacts;
  late RecordingDialer dialer;
  late RecordingComposer composer;
  late AppNotifier notices;
  late FakePositionReader where;

  Future<void> boot(String language, {String? country = 'SA'}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    gate = FakeGate();
    connections = FakeConnections();
    contacts = FakeContacts();
    dialer = RecordingDialer();
    notices = AppNotifier();
    where = FakePositionReader();
    composer = RecordingComposer();
    final CallLauncher calls = CallLauncher(dialer, composer);
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<SafetyHelpCubit>(
        () => SafetyHelpCubit(gate, connections, contacts, calls),
      )
      ..registerFactory<EmergencyCubit>(
        () => EmergencyCubit(
          MemoryCountryRepository(country),
          BundledEmergencyRepository(EmergencyDataSource()),
          calls,
        ),
      )
      ..registerFactory<EmergencyLocationCubit>(
        () => stillLocationCubit(where),
      );
  }

  tearDown(sl.reset);

  Future<void> pump(
    WidgetTester tester, {
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
    final GoRouter router = AppRouter.create(
      initialLocation: AppRoutes.safetyHelpPath,
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
  }

  Finder text(String key) => find.text(key.tr());

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    for (int i = 0; i < 3; i++) {
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
    }
    await tester.pumpAndSettle();
  }

  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing open: what SafeRide cannot do, and the ways to '
      'reach help yourself', (WidgetTester tester) async {
    await boot('en');
    await pump(tester);
    expect(text('safety.help.title'), findsOneWidget);
    expect(text('safety.help.none'), findsOneWidget);
    expect(text('safety.help.okay'), findsNothing);
    expect(text('safety.help.share.action'), findsNothing);
    expect(text('safety.help.emergency.heading'), findsOneWidget);
    expect(find.textContaining('911'), findsWidgets);
  });

  testWidgets('an open escalation: when, that nobody was contacted, and '
      '"I\'m okay" closes it', (WidgetTester tester) async {
    await boot('en');
    gate.open = OpenEscalation(
      checkId: 'e1-check',
      journeyId: 'j1',
      timedOutAt: at,
    );
    await pump(tester);
    expect(find.textContaining('No answer was recorded at'), findsOneWidget);
    final String body = 'safety.help.open.body'.tr();
    expect(body, contains('nobody has been contacted'));
    expect(find.text(body), findsOneWidget);
    await tester.scrollUntilVisible(text('safety.help.share.action'), 300);
    expect(text('safety.help.share.action'), findsOneWidget);
    await tester.scrollUntilVisible(text('safety.help.okay'), -300);

    await tap(tester, text('safety.help.okay'));
    expect(gate.resolved, <String>['e1-check']);
    expect(text('safety.help.okayDone'), findsOneWidget);
    expect(text('safety.help.okay'), findsNothing);
    await outlast(tester);
  });

  testWidgets('Call on an emergency number opens the phone app and claims '
      'nothing more', (WidgetTester tester) async {
    await boot('en');
    await pump(tester);
    await tap(tester, find.byType(FilledButton));
    expect(dialer.opened, hasLength(1));
    expect(dialer.opened.single, matches(RegExp(r'^\+?[0-9]{2,15}$')));
    expect(find.textContaining("can't see whether"), findsWidgets);
    expect(find.textContaining('called'), findsNothing);
    await outlast(tester);
  });

  testWidgets('no country chosen: no numbers guessed', (
    WidgetTester tester,
  ) async {
    await boot('en', country: null);
    await pump(tester);
    expect(text('safety.emergency.choose.title'), findsOneWidget);
    expect(find.textContaining('911'), findsNothing);
    expect(find.textContaining('999'), findsNothing);
  });

  testWidgets('people: connected by name, what cannot be done for them, and '
      'saved numbers with Call', (WidgetTester tester) async {
    await boot('en');
    connections.all = <ConnectionModel>[
      ConnectionModel(
        ownerUid: 'sara',
        contactUid: 'omar',
        contactName: 'Omar Ali',
        status: ConnectionStatus.accepted,
        inviteId: 'i',
        createdAt: at,
        acceptedAt: at,
      ),
      ConnectionModel(
        ownerUid: 'sara',
        contactUid: 'mona',
        contactName: 'Mona Ended',
        status: ConnectionStatus.revoked,
        inviteId: 'j',
        createdAt: at,
        acceptedAt: at,
      ),
    ];
    contacts.all = <TrustedContactModel>[
      TrustedContactModel(
        id: 'c1',
        fullName: 'Lina Saleh',
        phone: '+966551112222',
        createdAt: at,
      ),
    ];
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Lina Saleh'), 300);
    expect(find.text('Omar Ali'), findsOneWidget);
    expect(find.text('Mona Ended'), findsNothing);
    expect(text('safety.help.people.cannotAlert'), findsOneWidget);
    expect(find.textContaining('966'), findsNothing, reason: 'no numbers');

    await tap(
      tester,
      find.descendant(
        of: find.ancestor(
          of: find.text('Lina Saleh'),
          matching: find.byType(HelpPerson),
        ),
        matching: text('safety.reach.call'),
      ),
    );
    expect(dialer.opened.last, '+966551112222');
    await outlast(tester);
  });

  testWidgets('Arabic, dark: right to left, nothing claimed', (
    WidgetTester tester,
  ) async {
    await boot('ar');
    gate.open = OpenEscalation(
      checkId: 'e1-check',
      journeyId: 'j1',
      timedOutAt: at,
    );
    await pump(tester, mode: ThemeMode.dark);
    expect(find.text('طلب المساعدة'), findsOneWidget);
    expect(find.textContaining('لم يُتواصل مع أحد'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('طلب المساعدة'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batch 20, an open escalation: "I\'m okay" first, then the '
      'directory with its country, where you are, sharing and people — and '
      'nothing dialled, read or shared on its own', (
    WidgetTester tester,
  ) async {
    await boot('en');
    gate.open = OpenEscalation(
      checkId: 'e1-check',
      journeyId: 'j1',
      timedOutAt: at,
    );
    await pump(tester);
    final double okay = tester.getTopLeft(text('safety.help.okay')).dy;
    final double numbers = tester
        .getTopLeft(text('safety.help.emergency.heading'))
        .dy;
    expect(okay, lessThan(numbers));
    expect(find.text('Saudi Arabia'), findsOneWidget);
    expect(text('safety.emergency.change'), findsOneWidget);
    expect(text('safety.emergency.callNote'), findsOneWidget);

    for (final String key in <String>[
      'safety.location.heading',
      'safety.help.share.action',
      'safety.help.people.heading',
    ]) {
      await tester.scrollUntilVisible(text(key), 300);
      expect(text(key), findsOneWidget);
    }
    expect(dialer.opened, isEmpty);
    expect(where.readings, 0);
    expect(
      GoRouterState.of(tester.element(text('safety.help.share.action'))).name,
      AppRoutes.safetyHelp,
      reason: 'sharing is only offered, never started',
    );
  });

  testWidgets('Batch 20: a saved number typed with spaces and dashes is '
      'called as dialled digits', (WidgetTester tester) async {
    await boot('en');
    contacts.all = <TrustedContactModel>[
      TrustedContactModel(
        id: 'c1',
        fullName: 'Lina Saleh',
        phone: '+966 55-000 0001',
        createdAt: at,
      ),
    ];
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Lina Saleh'), 300);
    await tap(
      tester,
      find.descendant(
        of: find.ancestor(
          of: find.text('Lina Saleh'),
          matching: find.byType(HelpPerson),
        ),
        matching: text('safety.reach.call'),
      ),
    );
    expect(dialer.opened, <String>['+966550000001']);
    await outlast(tester);
  });

  group('Batch 21: reaching saved people', () {
    Finder inCard(String name, Finder what) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(HelpPerson)),
      matching: what,
    );

    void saved(List<(String, String, String)> people) =>
        contacts.all = <TrustedContactModel>[
          for (final (String id, String name, String phone) in people)
            TrustedContactModel(
              id: id,
              fullName: name,
              phone: phone,
              createdAt: at,
            ),
        ];

    testWidgets('Message opens the messaging app with the short text, which '
        'the user sends; the notice never says it was sent', (
      WidgetTester tester,
    ) async {
      await boot('en');
      saved(<(String, String, String)>[
        ('c1', 'Lina Saleh', '+966 55 000 0001'),
      ]);
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Lina Saleh'), 300);
      expect(text('safety.help.people.messageNote'), findsOneWidget);
      await tap(tester, inCard('Lina Saleh', text('safety.reach.message')));
      expect(composer.composed, <(String, String)>[
        (
          '+966550000001',
          'I may need assistance. Please contact me as soon as possible.',
        ),
      ]);
      expect(dialer.opened, isEmpty);
      expect(notices.current?.title, 'safety.reach.compose.opened.title'.tr());
      expect(notices.current?.message, contains('send it yourself'));
      expect(notices.current?.message, contains("can't see"));
      await outlast(tester);
    });

    testWidgets('in Arabic, the text is Arabic', (WidgetTester tester) async {
      await boot('ar');
      saved(<(String, String, String)>[('c1', 'Lina Saleh', '0550000001')]);
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Lina Saleh'), 300);
      await tap(tester, inCard('Lina Saleh', find.text('رسالة')));
      expect(
        composer.composed.single.$2,
        'قد أحتاج إلى المساعدة. أرجو التواصل معي في أقرب وقت ممكن.',
      );
      await outlast(tester);
    });

    for (final (ComposeOutcome outcome, String kind)
        in <(ComposeOutcome, String)>[
          (ComposeOutcome.noMessaging, 'noMessaging'),
          (ComposeOutcome.failed, 'failed'),
        ]) {
      testWidgets('a messaging app that $kind is said as it is', (
        WidgetTester tester,
      ) async {
        await boot('en');
        composer.outcome = outcome;
        saved(<(String, String, String)>[('c1', 'Lina Saleh', '0550000001')]);
        await pump(tester);
        await tester.scrollUntilVisible(find.text('Lina Saleh'), 300);
        await tap(tester, inCard('Lina Saleh', text('safety.reach.message')));
        expect(notices.current?.title, 'safety.reach.compose.$kind.title'.tr());
        expect(notices.current?.message, contains('Lina Saleh'));
        await outlast(tester);
      });
    }

    testWidgets('a number that cannot be used offers no buttons, and says '
        'why', (WidgetTester tester) async {
      await boot('en');
      saved(<(String, String, String)>[
        ('c1', 'Long Number', '+966 55 000 0001 234 5'),
        ('c2', 'No Number', ''),
      ]);
      await pump(tester);
      await tester.scrollUntilVisible(find.text('No Number'), 300);
      expect(
        inCard('Long Number', text('safety.reach.invalid')),
        findsOneWidget,
      );
      expect(inCard('No Number', text('safety.reach.missing')), findsOneWidget);
      expect(find.byType(ContactReachButtons), findsNWidgets(2));
      expect(inCard('Long Number', find.byType(TextButton)), findsNothing);
      expect(text('safety.help.people.messageNote'), findsNothing);
    });

    testWidgets('a connected person has no Call or Message: a connection '
        'shares no number', (WidgetTester tester) async {
      await boot('en');
      connections.all = <ConnectionModel>[
        ConnectionModel(
          ownerUid: 'sara',
          contactUid: 'omar',
          contactName: 'Omar Ali',
          status: ConnectionStatus.accepted,
          inviteId: 'i',
          createdAt: at,
          acceptedAt: at,
        ),
      ];
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Omar Ali'), 300);
      expect(inCard('Omar Ali', find.byType(TextButton)), findsNothing);
      expect(
        inCard('Omar Ali', find.byType(ContactReachButtons)),
        findsNothing,
      );
      expect(
        'safety.help.people.cannotAlert'.tr(),
        contains("doesn't share their phone number"),
      );
    });

    testWidgets('texting during an open escalation leaves it open, and '
        '"I\'m okay" still first', (WidgetTester tester) async {
      await boot('en');
      gate.open = OpenEscalation(
        checkId: 'e1-check',
        journeyId: 'j1',
        timedOutAt: at,
      );
      saved(<(String, String, String)>[('c1', 'Lina Saleh', '0550000001')]);
      await pump(tester);
      await tester.scrollUntilVisible(find.text('Lina Saleh'), 300);
      await tap(tester, inCard('Lina Saleh', text('safety.reach.message')));
      expect(gate.resolved, isEmpty);
      await tester.scrollUntilVisible(text('safety.help.okay'), -300);
      expect(text('safety.help.okay'), findsOneWidget);
      await outlast(tester);
    });
  });
}
