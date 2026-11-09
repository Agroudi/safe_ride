import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_asset_loader.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/invite_failure.dart';
import 'package:safe_ride/features/safety/data/repository/cloud_contact_invite_repository.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_received_alerts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_invite_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_links_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/received_alerts_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contact_invite_state.dart';
import 'package:safe_ride/features/safety/presentation/pages/accept_invite_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/received_alerts_page.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_alerts_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';

import '../invite_fakes.dart';
import '../help_fakes.dart';

class _Session implements SessionReader {
  _Session(this.uid);

  final String uid;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      SessionUser(id: uid, fullName: 'Omar');
}

/// Records instead of opening: no test reaches a real dialer.
class _Dialer implements PhoneDialer {
  final List<String> opened = <String>[];

  @override
  Future<DialOutcome> open(String number) async {
    opened.add(number);
    return DialOutcome.opened;
  }
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late FakeInvites invites;
  late AppNotifier notices;
  late FakeFirebaseFirestore db;
  late _Dialer dialer;

  Future<void> boot(String language) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    invites = FakeInvites();
    notices = AppNotifier();
    db = FakeFirebaseFirestore();
    dialer = _Dialer();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<ContactLinksCubit>(() => ContactLinksCubit(invites))
      ..registerFactory<ContactInviteCubit>(() => ContactInviteCubit(invites))
      ..registerFactory<ReceivedAlertsCubit>(
        () => ReceivedAlertsCubit(
          FirestoreReceivedAlertsRepository(db, _Session('omar')),
          CallLauncher(dialer, RecordingComposer()),
        ),
      );
  }

  tearDown(sl.reset);

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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
              extensions: const <ThemeExtension<dynamic>>[AppColors.light],
            ),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder text(String key) => find.text(key.tr());

  Future<void> seedAlert({String? phone = '+966500000001'}) =>
      db.doc('users/omar/receivedAlerts/sara_e1-check').set(<String, Object?>{
        'fromName': 'Sara Ahmed',
        'fromPhone': phone,
        'type': 'prolongedStop',
        'eventAt': DateTime.utc(2026, 11, 4, 7, 5),
        'createdAt': DateTime.utc(2026, 11, 4, 7, 6),
      });

  group('the contact card', () {
    const Widget card = Scaffold(
      body: ContactAlertsCard(contactId: 'c1', phone: '+966 50 000 0002'),
    );

    testWidgets('not linked: says a number alone reaches nobody', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, card);
      expect(text('safety.invite.notLinked'), findsOneWidget);
      expect(text('safety.invite.create'), findsOneWidget);
    });

    testWidgets('linked for this number: says so, no code', (
      WidgetTester tester,
    ) async {
      await boot('en');
      invites.linked['c1'] = '966500000002';
      await show(tester, card);
      expect(text('safety.invite.linked'), findsOneWidget);
      expect(text('safety.invite.create'), findsNothing);
    });

    testWidgets('linked for an older number: not linked', (
      WidgetTester tester,
    ) async {
      await boot('en');
      invites.linked['c1'] = '111';
      await show(tester, card);
      expect(text('safety.invite.notLinked'), findsOneWidget);
    });

    testWidgets('a code is made once and shown with its limits', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, card);
      await tester.tap(text('safety.invite.create'));
      await tester.pumpAndSettle();
      expect(invites.created, <String>['c1']);
      expect(find.text('ABCDE-23456'), findsOneWidget);
      expect(find.textContaining('It works once'), findsOneWidget);
    });

    testWidgets('the backend missing is said, not hidden', (
      WidgetTester tester,
    ) async {
      await boot('en');
      invites.failure = InviteFailureCode.unavailable;
      await show(tester, card);
      await tester.tap(text('safety.invite.create'));
      await tester.pumpAndSettle();
      expect(notices.current?.message, 'safety.invite.errors.unavailable'.tr());
      await tester.pump(AppDurations.noticeLong);
    });
  });

  group('accepting an invite', () {
    testWidgets('says what it agrees to, and that no location is seen', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await show(tester, const AcceptInvitePage());
      expect(find.textContaining('never their location'), findsOneWidget);
    });

    testWidgets('a code is required', (WidgetTester tester) async {
      await boot('en');
      await show(tester, const AcceptInvitePage());
      await tester.tap(text('safety.invite.accept'));
      await tester.pumpAndSettle();
      expect(invites.accepted, isEmpty);
    });

    testWidgets('a wrong code keeps the screen and says why', (
      WidgetTester tester,
    ) async {
      await boot('en');
      invites.failure = InviteFailureCode.invalidCode;
      await show(tester, const AcceptInvitePage());
      await tester.enterText(find.byType(TextFormField), 'AAAAA-BBBBB');
      await tester.tap(text('safety.invite.accept'));
      await tester.pumpAndSettle();
      expect(invites.accepted, <String>['AAAAA-BBBBB']);
      expect(notices.current?.message, 'safety.invite.errors.invalidCode'.tr());
      expect(find.byType(AcceptInvitePage), findsOneWidget);
      await tester.pump(AppDurations.noticeLong);
    });

    test('double taps accept once', () async {
      final FakeInvites slow = FakeInvites()..hold = Completer<void>();
      final ContactInviteCubit cubit = ContactInviteCubit(slow);
      final Future<void> first = cubit.accept('X');
      await cubit.accept('X');
      slow.hold!.complete();
      await first;
      expect(slow.accepted, hasLength(1));
      expect(cubit.state, const InviteAccepted('Sara Ahmed'));
      await cubit.close();
    });
  });

  group('alerts received', () {
    testWidgets('nothing yet: said plainly', (WidgetTester tester) async {
      await boot('en');
      await show(tester, const ReceivedAlertsPage());
      expect(text('safety.alerts.empty.title'), findsOneWidget);
    });

    testWidgets('says what is known and what is not, in English', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await seedAlert();
      await show(tester, const ReceivedAlertsPage());
      expect(find.text('Please check on Sara Ahmed'), findsOneWidget);
      expect(find.textContaining('a long stop'), findsOneWidget);
      expect(find.textContaining("doesn't confirm"), findsOneWidget);
      expect(
        find.textContaining("hasn't contacted emergency services"),
        findsOneWidget,
      );
      expect(find.textContaining('accident'), findsNothing);
      expect(find.textContaining('injured'), findsNothing);
    });

    testWidgets('in Arabic, right to left, in the same careful words', (
      WidgetTester tester,
    ) async {
      await boot('ar');
      await seedAlert();
      await show(tester, const ReceivedAlertsPage());
      expect(find.text('يُرجى الاطمئنان على Sara Ahmed'), findsOneWidget);
      expect(find.textContaining('لم يتصل SafeRide'), findsOneWidget);
      expect(find.textContaining('حادث'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(ReceivedAlertsPage))),
        TextDirection.rtl,
      );
    });

    testWidgets('Call opens the phone app only on a tap', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await seedAlert();
      await show(tester, const ReceivedAlertsPage());
      expect(dialer.opened, isEmpty);
      await tester.tap(find.text('Call Sara Ahmed'));
      await tester.pumpAndSettle();
      expect(dialer.opened, <String>['+966500000001']);
      await tester.pump(AppDurations.noticeLong);
    });

    testWidgets('no number on their profile: no Call', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await seedAlert(phone: null);
      await show(tester, const ReceivedAlertsPage());
      expect(find.text('Call Sara Ahmed'), findsNothing);
    });

    test('one contact never reads another\'s alerts', () async {
      final FakeFirebaseFirestore store = FakeFirebaseFirestore();
      await store.doc('users/omar/receivedAlerts/a').set(<String, Object?>{
        'fromName': 'Sara',
        'type': 'prolongedStop',
        'eventAt': DateTime.utc(2026),
        'createdAt': DateTime.utc(2026),
      });
      expect(
        await FirestoreReceivedAlertsRepository(
          store,
          _Session('lina'),
        ).alerts(),
        isEmpty,
      );
      expect(
        await FirestoreReceivedAlertsRepository(
          store,
          _Session('omar'),
        ).alerts(),
        hasLength(1),
      );
    });
  });

  test('the backend\'s answers, by code', () {
    for (final (String code, InviteFailureCode failure)
        in <(String, InviteFailureCode)>[
          ('invalid-argument', InviteFailureCode.invalidCode),
          ('failed-precondition', InviteFailureCode.noLongerValid),
          ('permission-denied', InviteFailureCode.ownInvite),
          ('unavailable', InviteFailureCode.network),
          // A function that is not deployed: never "wrong code".
          ('not-found', InviteFailureCode.unavailable),
          ('internal', InviteFailureCode.unavailable),
        ]) {
      expect(CloudContactInviteRepository.failureOf(code), failure);
    }
  });
}
