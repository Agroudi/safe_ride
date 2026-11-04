import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_number_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/country/country_fakes.dart';

/// Answers [outcome] and remembers the numbers; never opens anything.
class _Dialer implements PhoneDialer {
  DialOutcome outcome = DialOutcome.opened;
  final List<String> dialled = <String>[];

  @override
  Future<DialOutcome> open(String number) async {
    dialled.add(number);
    return outcome;
  }
}

/// A dataset with nothing for any country.
class _Empty implements EmergencyRepository {
  @override
  Future<EmergencyCountry?> forCountry(String code) async => null;
}

void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late AppNotifier notices;
  late MemoryCountryRepository countries;
  late _Dialer dialer;

  /// No Firestore, no network: everything comes from the phone.
  Future<void> boot(
    String language, {
    String? country,
    EmergencyRepository? numbers,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'locale': language,
    });
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    notices = AppNotifier();
    countries = MemoryCountryRepository(country);
    dialer = _Dialer();
    await sl.reset();
    sl
      ..registerSingleton<AppNotifier>(notices)
      ..registerFactory<EmergencyCubit>(
        () => EmergencyCubit(
          countries,
          numbers ?? BundledEmergencyRepository(EmergencyDataSource()),
          dialer,
        ),
      );
  }

  tearDown(sl.reset);

  Future<void> open(
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
    router.pushNamed(AppRoutes.emergencyInfo);
    await tester.pumpAndSettle();
  }

  Finder text(String key) => find.text(key.tr());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> outlast(WidgetTester tester) async {
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  }

  testWidgets('no country yet: it asks, never guesses; the choice shows '
      'that country\'s numbers', (WidgetTester tester) async {
    await boot('en');
    await open(tester);
    expect(text('safety.emergency.warning'), findsOneWidget);
    expect(text('safety.emergency.choose.title'), findsOneWidget);
    expect(find.byType(EmergencyNumberTile), findsNothing);
    expect(countries.reconciled, greaterThan(0));

    await tap(tester, text('safety.emergency.choose.action'));
    // Every country, named in both languages.
    expect(find.text('Qatar'), findsOneWidget);
    expect(find.text('قطر'), findsOneWidget);
    expect(find.text('Egypt'), findsOneWidget);
    expect(find.text('مصر'), findsOneWidget);
    await tap(tester, find.text('Qatar'));

    expect(countries.code, 'QA');
    expect(find.text('Qatar'), findsOneWidget);
    expect(find.byType(EmergencyNumberTile), findsOneWidget);
    expect(find.text('999'), findsOneWidget);
    expect(text('safety.emergency.services.general'), findsOneWidget);
    expect(
      find.text('One number for police, ambulance and fire.'),
      findsOneWidget,
    );
    expect(find.textContaining('Hamad Medical Corporation'), findsOneWidget);
  });

  testWidgets('Saudi Arabia: 911 where it applies, then each service', (
    WidgetTester tester,
  ) async {
    await boot('en', country: 'SA');
    await open(tester);
    expect(find.textContaining('Riyadh, Makkah, Madinah'), findsOneWidget);
    for (final String n in <String>['911', '999', '997', '998', '993', '996']) {
      await tester.scrollUntilVisible(find.text(n), 200);
      expect(find.text(n), findsOneWidget);
    }
    expect(text('safety.emergency.about.ambulance'), findsOneWidget);
  });

  testWidgets('changing the country changes the numbers', (
    WidgetTester tester,
  ) async {
    await boot('en', country: 'SA');
    await open(tester);
    await tap(tester, text('safety.emergency.change'));
    await tap(tester, find.text('Egypt'));
    expect(find.text('122'), findsOneWidget);
    expect(find.text('911'), findsNothing);
  });

  for (final (DialOutcome outcome, String kind) in <(DialOutcome, String)>[
    (DialOutcome.opened, 'opened'),
    (DialOutcome.noDialer, 'noDialer'),
    (DialOutcome.failed, 'failed'),
    (DialOutcome.invalidNumber, 'invalidNumber'),
  ]) {
    testWidgets('Call: $kind is said as it is — never "called"', (
      WidgetTester tester,
    ) async {
      await boot('en', country: 'KW');
      dialer.outcome = outcome;
      await open(tester);
      await tap(tester, text('safety.emergency.call'));
      expect(dialer.dialled, <String>['112']);
      expect(notices.current?.title, 'safety.emergency.dial.$kind.title'.tr());
      expect(notices.current?.message, contains('112'));
      if (outcome == DialOutcome.opened) {
        expect(notices.current?.message, contains("can't see"));
      }
      await outlast(tester);
    });
  }

  testWidgets('a country without checked numbers shows none', (
    WidgetTester tester,
  ) async {
    await boot('en', country: 'OM', numbers: _Empty());
    await open(tester);
    expect(text('safety.emergency.unavailable.title'), findsOneWidget);
    expect(find.textContaining('Oman'), findsWidgets);
    expect(find.byType(EmergencyNumberTile), findsNothing);
  });

  testWidgets('in Arabic: right to left, Arabic names, digits as dialled', (
    WidgetTester tester,
  ) async {
    await boot('ar', country: 'BH');
    await open(tester);
    expect(find.text('البحرين'), findsOneWidget);
    expect(find.text('الطوارئ'), findsOneWidget);
    expect(find.text('الحوادث المرورية'), findsOneWidget);
    expect(
      find.text('رقم واحد لكلٍّ من الشرطة والإسعاف والإطفاء.'),
      findsOneWidget,
    );
    final Finder tile = find.byType(EmergencyNumberTile).first;
    expect(Directionality.of(tester.element(tile)), TextDirection.rtl);
    // The number reads left to right even in Arabic.
    final Text number = tester.widget<Text>(find.text('999'));
    expect(number.textDirection, TextDirection.ltr);
    // The Call button sits at the reading end: the left.
    final Rect call = tester.getRect(
      find.descendant(of: tile, matching: find.byType(FilledButton)),
    );
    expect(call.center.dx, lessThan(tester.getRect(tile).center.dx));
  });

  for (final (ThemeMode mode, AppColors palette) in <(ThemeMode, AppColors)>[
    (ThemeMode.light, AppColors.light),
    (ThemeMode.dark, AppColors.dark),
  ]) {
    testWidgets('drawn from the ${mode.name} palette', (
      WidgetTester tester,
    ) async {
      await boot('en', country: 'AE');
      await open(tester, theme: mode);
      final Container tile = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(EmergencyNumberTile).first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect((tile.decoration! as BoxDecoration).color, palette.surface);
    });
  }
}
