import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/preferences/preferences_state.dart';
import 'package:safe_ride/core/shared_widgets/preference_option.dart';
import 'package:safe_ride/core/shared_widgets/preferences_sheet.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The preferences sheet against the real cubit, the real translation files
/// and mocked SharedPreferences — what the app wires, minus the router and
/// `AppTheme` (google_fonts would try to download Cairo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // easy_localization logs every load; keep the test output readable.
  EasyLocalization.logger.enableBuildModes = [];

  late SharedPreferences prefs;
  late PreferencesCubit cubit;

  setUp(() async {
    // A first launch whose saved language is Arabic, so no result depends on
    // the locale of the machine running the test.
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'ar'});
    // ⚠️ The asset bundle caches each file's Future, and one created inside an
    // earlier test's fake-async zone never completes in the next: the
    // translations would never load and the app would stay blank.
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    prefs = await SharedPreferences.getInstance();
    cubit = PreferencesCubit(AppPreferences(prefs));
  });

  tearDown(() => cubit.close());

  /// Pumps the harness on a phone of [size] — the 390 × 844 design frame by
  /// default — and opens the sheet.
  Future<void> openSheet(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Harness(cubit: cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_Harness.opener));
    await tester.pumpAndSettle();

    // The translations loaded: a missing file would show the raw key.
    expect(find.text('التفضيلات'), findsOneWidget);
  }

  BuildContext sheet(WidgetTester tester) =>
      tester.element(find.byType(PreferencesSheet));

  /// The option labelled with translation [key] in the current language.
  Finder option(String key) => find.widgetWithText(PreferenceOption, key.tr());

  /// Drops the in-memory copy, so a value read back came from the store.
  Future<SharedPreferences> reloaded() {
    SharedPreferences.resetStatic();
    return SharedPreferences.getInstance();
  }

  testWidgets('tapping Dark switches the theme and saves it', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    expect(cubit.state.themeMode, ThemeMode.system);

    await tester.tap(option('preferences.themes.dark'));
    await tester.pumpAndSettle();

    expect(cubit.state.themeMode, ThemeMode.dark);
    expect(AppPreferences(await reloaded()).themeMode, ThemeMode.dark);
    // Still open, and already painted with the dark palette.
    expect(find.byType(PreferencesSheet), findsOneWidget);
    expect(Theme.of(sheet(tester)).brightness, Brightness.dark);
  });

  testWidgets('tapping English switches the language and the direction', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    expect(Directionality.of(sheet(tester)), TextDirection.rtl);

    await tester.tap(option('preferences.languages.en'));
    await tester.pumpAndSettle();

    expect(sheet(tester).locale, AppLocales.english);
    expect(Directionality.of(sheet(tester)), TextDirection.ltr);
    // Re-rendered in place: the open sheet now reads in English.
    expect(find.text('Preferences'), findsOneWidget);
    // Saved by easy_localization for the next launch.
    expect((await reloaded()).getString('locale'), 'en');
  });

  // `.fx` scales by the shorter side, so a 56 design height drops to 42 on a
  // 360 × 640 phone unless it is floored in logical pixels.
  for (final Size size in <Size>[const Size(360, 640), const Size(320, 568)]) {
    testWidgets('every row keeps a 48dp tap target on $size', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await openSheet(tester, size: size);

      for (final Element row in find.byType(PreferenceOption).evaluate()) {
        expect(
          row.size!.height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
        );
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });
  }

  // System is the default, so its hint is on a selected row the first time
  // anyone opens the sheet: it must reach 4.5:1 on the selected tint.
  testWidgets('the hint under a selected row reaches 4.5:1', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    const AppColors colors = AppColors.light;

    final Text hint = tester.widget<Text>(
      find.text('preferences.systemHint'.tr()),
    );
    expect(
      _contrast(hint.style!.color!, colors.tint(colors.primary)),
      greaterThanOrEqualTo(4.5),
    );

    // Unselected, it sits on the plain surface and stays the quieter tone.
    await tester.tap(option('preferences.themes.light'));
    await tester.pumpAndSettle();
    final Text quiet = tester.widget<Text>(
      find.text('preferences.systemHint'.tr()),
    );
    expect(quiet.style!.color, colors.textMuted);
    expect(
      _contrast(quiet.style!.color!, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('the chosen options are announced as selected', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await openSheet(tester);

    expect(
      tester.getSemantics(option('preferences.themes.system')),
      isSemantics(
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    expect(
      tester.getSemantics(option('preferences.themes.dark')),
      isSemantics(
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    expect(
      tester.getSemantics(option('preferences.languages.ar')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(option('preferences.languages.en')),
      isSemantics(hasSelectedState: true, isSelected: false),
    );

    // The announcement follows the choice.
    await tester.tap(option('preferences.themes.dark'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(option('preferences.themes.dark')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(option('preferences.themes.system')),
      isSemantics(hasSelectedState: true, isSelected: false),
    );

    semantics.dispose();
  });
}

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The app's shell in miniature: EasyLocalization outermost, ScreenUtil for
/// `.fx`, the cubit above `MaterialApp`, and the theme mode and locale read
/// the way `main.dart` reads them — so a choice in the sheet rebuilds the app
/// underneath it exactly as it would on a phone.
class _Harness extends StatelessWidget {
  const _Harness({required this.cubit});

  final PreferencesCubit cubit;

  static const Key opener = Key('open-preferences');

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: AppLocales.supported,
      fallbackLocale: AppLocales.fallback,
      path: AppLocales.translationsPath,
      ignorePluralRules: false,
      child: ScreenUtilInit(
        designSize: const Size(AppDesign.width, AppDesign.height),
        minTextAdapt: true,
        builder: (BuildContext context, _) =>
            BlocProvider<PreferencesCubit>.value(
              value: cubit,
              child:
                  BlocSelector<PreferencesCubit, PreferencesState, ThemeMode>(
                    selector: (PreferencesState state) => state.themeMode,
                    builder: (BuildContext context, ThemeMode mode) =>
                        MaterialApp(
                          theme: ThemeData(
                            extensions: const <ThemeExtension<dynamic>>[
                              AppColors.light,
                            ],
                          ),
                          darkTheme: ThemeData(
                            brightness: Brightness.dark,
                            extensions: const <ThemeExtension<dynamic>>[
                              AppColors.dark,
                            ],
                          ),
                          themeMode: mode,
                          locale: context.locale,
                          supportedLocales: context.supportedLocales,
                          localizationsDelegates: context.localizationDelegates,
                          home: const _Page(),
                        ),
                  ),
            ),
      ),
    );
  }
}

/// A page that opens the sheet from its own context, as `WelcomePage` does.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: _Harness.opener,
          onPressed: () => showPreferencesSheet(context),
          child: const Text('open'),
        ),
      ),
    );
  }
}
