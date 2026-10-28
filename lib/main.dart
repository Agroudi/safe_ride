import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/preferences/preferences_state.dart';
import 'package:safe_ride/core/router/app_back_dispatcher.dart';
import 'package:safe_ride/core/router/app_router.dart';
import 'package:safe_ride/core/theme/app_theme.dart';
import 'package:safe_ride/core/theme/system_bars.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: every design frame is a phone held upright, and the sizing
  // system scales against that width. Landscape needs its own design.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Draw behind the status and navigation bars on every Android version, as
  // Android 15+ already forces — `SystemBars` keeps both transparent and every
  // screen pads itself with `SafeArea`.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await EasyLocalization.ensureInitialized();
  // Journey dates are drawn in `ar_EG` digits (`LocaleNumbers.dateTime`).
  await initializeDateFormatting();
  await setupServiceLocator();

  // The saved theme's bar icons from the very first frame — see
  // `SystemBars.styleForMode`.
  SystemChrome.setSystemUIOverlayStyle(
    SystemBars.styleForMode(sl<PreferencesCubit>().state.themeMode),
  );

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      fallbackLocale: AppLocales.fallback,
      // No `startLocale`: the saved choice wins, then the device language,
      // then the fallback — see `AppLocales`.
      path: AppLocales.translationsPath,
      // ⚠️ The package defaults this to `true`, which silently replaces the
      // CLDR plural rules with a zero/one/two/other match — Arabic's `few` and
      // `many` forms are then never read («٣ نموذج» instead of «٣ نماذج»).
      ignorePluralRules: false,
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  /// Built once, beside the router it drives; rebuilding it every frame would
  /// forget the "press back again" moment.
  static final AppBackButtonDispatcher _backDispatcher =
      AppBackButtonDispatcher(
        router: AppRouter.router,
        notifier: sl<AppNotifier>(),
      );

  @override
  Widget build(BuildContext context) {
    // ⚠️ Outermost: both themes are sized with `.fx`, which needs ScreenUtil.
    return ScreenUtilInit(
      designSize: const Size(AppDesign.width, AppDesign.height),
      minTextAdapt: true,
      builder: (BuildContext context, _) =>
          BlocProvider<PreferencesCubit>.value(
            value: sl<PreferencesCubit>(),
            // Only a theme change rebuilds the app, not every preference.
            child: BlocSelector<PreferencesCubit, PreferencesState, ThemeMode>(
              selector: (PreferencesState state) => state.themeMode,
              builder: (BuildContext context, ThemeMode mode) =>
                  MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    onGenerateTitle: (BuildContext context) => 'app.name'.tr(),
                    theme: AppTheme.light(),
                    darkTheme: AppTheme.dark(),
                    themeMode: mode,
                    // A theme change crossfades (`AppColors.lerp`); it cuts
                    // when the system asks for no animations.
                    themeAnimationStyle: MediaQuery.disableAnimationsOf(context)
                        ? AnimationStyle.noAnimation
                        : const AnimationStyle(
                            duration: AppDurations.short,
                            curve: AppCurves.move,
                          ),
                    // ⚠️ The root stage: the route fade-through dips through
                    // this colour. Without it the dip shows the opaque
                    // FlutterView's black. Notifications sit above every
                    // route, so one survives the navigation it announces.
                    builder: (BuildContext context, Widget? child) =>
                        ColoredBox(
                          color: context.appColors.background,
                          child: SystemBars(
                            child: NotificationHost(
                              notifier: sl<AppNotifier>(),
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    // ⚠️ In pieces, not `routerConfig:` — see
                    // `AppBackButtonDispatcher`.
                    routerDelegate: AppRouter.router.routerDelegate,
                    routeInformationParser:
                        AppRouter.router.routeInformationParser,
                    routeInformationProvider:
                        AppRouter.router.routeInformationProvider,
                    backButtonDispatcher: _backDispatcher,
                  ),
            ),
          ),
    );
  }
}
