import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/logic/cubit/escalation_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_check_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/safety_check_host.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/safety_check_prompt.dart';
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
  late DateTime now;
  late FakeTimers timers;
  late MemoryIncidentRepository incidents;
  late MemorySafetyCheckRepository checks;
  late FirestoreJourneyRepository journeys;
  late SafetyCheckService service;
  late FakeEscalations escalations;
  late EscalationSync sync;
  late AppNotifier notices;

  Future<void> boot(String language) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    now = DateTime.now().toUtc();
    timers = FakeTimers(() => now);
    incidents = MemoryIncidentRepository();
    checks = MemorySafetyCheckRepository();
    journeys = FirestoreJourneyRepository(FakeFirebaseFirestore(), _Session());
    service = SafetyCheckService(
      incidents: incidents,
      checks: checks,
      journeys: journeys,
      session: _Session(),
      notifications: FakeSafetyNotifications(),
      inForeground: () => true,
      clock: () => now,
      timer: timers.call,
    );
    escalations = FakeEscalations();
    sync = EscalationSync(
      checks: checks,
      incidents: incidents,
      repository: escalations,
      session: _Session(),
      updates: service.changes,
      live: false,
      clock: () => now,
    );
    notices = AppNotifier();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<SafetyCheckCubit>(() => SafetyCheckCubit(service, sync))
      ..registerFactory<EscalationCubit>(
        () => EscalationCubit(checks, escalations, sync, _Session()),
      );
  }

  tearDown(sl.reset);

  /// A page under the host, an active journey, and one medium event: the
  /// prompt is up.
  Future<void> open(
    WidgetTester tester, {
    ThemeMode theme = ThemeMode.light,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        path: AppLocales.translationsPath,
        child: ScreenUtilInit(
          designSize: const Size(AppDesign.width, AppDesign.height),
          builder: (BuildContext context, _) => MaterialApp(
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
            builder: (_, Widget? child) => NotificationHost(
              notifier: notices,
              child: SafetyCheckHost(child: child!),
            ),
            home: const Scaffold(body: Center(child: Text('page'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await incidents.put(
      PotentialIncident(
        id: 'e1',
        journeyId: j.id,
        uid: 'sara',
        type: IncidentType.suddenDeceleration,
        status: IncidentStatus.detected,
        confidence: IncidentConfidence.medium,
        detectedAt: now,
        updatedAt: now,
        reason: 'test',
      ),
    );
    await tester.runAsync(() => service.idle);
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await sync.dispose();
      await service.dispose();
    });
  }

  Finder text(String key) => find.text(key.tr());

  testWidgets('one screen: the question, 15 seconds, "I\'m safe"', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await boot('en');
    await open(tester);

    expect(text('journeys.safetyCheck.title'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(text('journeys.safetyCheck.safe'), findsOneWidget);
    expect(find.textContaining('15 seconds, SafeRide only'), findsOneWidget);
    expect(find.textContaining("can't alert your trusted"), findsOneWidget);
    expect(find.bySemanticsLabel('15 seconds left'), findsOneWidget);
    expect(find.bySemanticsLabel("I'm safe"), findsOneWidget);
    semantics.dispose();
    await finish(tester);
  });

  testWidgets('the seconds come from the deadline, not from ticks', (
    WidgetTester tester,
  ) async {
    await boot('en');
    await open(tester);
    // Five seconds pass, but only one redraw happens (a frozen app).
    now = now.add(const Duration(seconds: 5));
    await tester.pump(SafetyCheckPrompt.refresh);
    expect(find.text('10'), findsOneWidget);
    // A rebuild never restarts it.
    await tester.pump(SafetyCheckPrompt.refresh);
    expect(find.text('10'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('"I\'m safe" closes it at once and says thanks', (
    WidgetTester tester,
  ) async {
    await boot('en');
    await open(tester);
    now = now.add(const Duration(seconds: 3));
    await tester.tap(text('journeys.safetyCheck.safe'));
    await tester.runAsync(() => service.idle);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SafetyCheckPrompt), findsNothing);
    expect(checks.all.single.status, SafetyCheckStatus.confirmedSafe);
    expect(notices.current?.title, 'journeys.safetyCheck.thanks'.tr());
    await tester.pump(AppDurations.noticeLong);
    await finish(tester);
  });

  testWidgets('no answer: said plainly, what is known so far, then Close', (
    WidgetTester tester,
  ) async {
    await boot('en');
    await open(tester);
    now = now.add(const Duration(seconds: 15));
    timers.fireDue();
    await tester.runAsync(() async {
      await service.idle;
      await sync.idle;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(text('journeys.safetyCheck.noAnswer.title'), findsOneWidget);
    expect(find.textContaining("doesn't mean anything"), findsOneWidget);
    expect(text('journeys.escalation.serviceUnavailable'), findsOneWidget);
    expect(find.textContaining('could not be alerted'), findsOneWidget);
    expect(text('journeys.escalation.retry'), findsNothing);
    expect(text('journeys.safetyCheck.safe'), findsNothing);
    expect(checks.all.single.status, SafetyCheckStatus.escalationReady);

    await tester.tap(text('journeys.safetyCheck.noAnswer.close'));
    await tester.pump();
    expect(find.byType(SafetyCheckPrompt), findsNothing);
    await finish(tester);
  });

  testWidgets('in Arabic: right to left, Arabic-Indic digits and plurals', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await boot('ar');
    await open(tester);
    expect(find.text('هل أنت بخير؟'), findsOneWidget);
    expect(find.text('١٥'), findsOneWidget);
    expect(find.text('أنا بخير'), findsOneWidget);
    expect(find.bySemanticsLabel('بقيت ١٥ ثانية'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(SafetyCheckPrompt))),
      TextDirection.rtl,
    );
    now = now.add(const Duration(seconds: 13));
    await tester.pump(SafetyCheckPrompt.refresh);
    expect(find.bySemanticsLabel('بقيت ثانيتان'), findsOneWidget);
    semantics.dispose();
    await finish(tester);
  });

  for (final (ThemeMode mode, AppColors palette) in <(ThemeMode, AppColors)>[
    (ThemeMode.light, AppColors.light),
    (ThemeMode.dark, AppColors.dark),
  ]) {
    testWidgets('drawn from the ${mode.name} palette', (
      WidgetTester tester,
    ) async {
      await boot('en');
      await open(tester, theme: mode);
      final Material card = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SafetyCheckPrompt),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, palette.surface);
      await finish(tester);
    });
  }

  testWidgets('at twice the text size it still fits, and "I\'m safe" works', (
    WidgetTester tester,
  ) async {
    await boot('en');
    await open(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(text('journeys.safetyCheck.safe'));
    await tester.tap(text('journeys.safetyCheck.safe'));
    await tester.runAsync(() => service.idle);
    await tester.pump();
    expect(checks.all.single.status, SafetyCheckStatus.confirmedSafe);
    await tester.pump(AppDurations.noticeLong);
    await finish(tester);
  });
}
