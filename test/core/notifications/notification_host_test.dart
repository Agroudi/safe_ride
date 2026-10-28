import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/semantics.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_card.dart';
import 'package:safe_ride/core/notifications/notification_host.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The host over a plain screen: where the card sits, how long it stays,
/// and what a screen reader hears.
void main() {
  EasyLocalization.logger.enableBuildModes = [];
  late AppNotifier notices;

  const AppNotification noAccount = AppNotification.error(
    title: 'Something went wrong',
    message: 'No account exists with this email address.',
  );

  setUp(() async {
    // No saved locale: a saved one would override each test's `startLocale`.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    rootBundle.clear();
    await EasyLocalization.ensureInitialized();
    notices = AppNotifier();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    Locale locale = AppLocales.english,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: AppLocales.supported,
        fallbackLocale: AppLocales.fallback,
        startLocale: locale,
        saveLocale: false,
        path: AppLocales.translationsPath,
        child: ScreenUtilInit(
          designSize: const Size(AppDesign.width, AppDesign.height),
          builder: (BuildContext context, _) => MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              extensions: <ThemeExtension<dynamic>>[
                if (dark) AppColors.dark else AppColors.light,
              ],
            ),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (_, Widget? child) =>
                NotificationHost(notifier: notices, child: child!),
            home: const Scaffold(body: Center(child: Text('screen'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows title, message, status word and a close button', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpHost(tester);
    notices.show(noAccount);
    await tester.pumpAndSettle();

    expect(find.text(noAccount.title), findsOneWidget);
    expect(find.text(noAccount.message!), findsOneWidget);
    // One live region, read status word first: "Error, Something went…".
    final SemanticsNode card = tester.getSemantics(
      find.byType(NotificationCard),
    );
    expect(card, isSemantics(isLiveRegion: true));
    expect(card.label, startsWith('notifications.kinds.error'.tr()));
    expect(card.label, contains(noAccount.title));
    expect(find.bySemanticsLabel('notifications.dismiss'.tr()), findsOne);
    semantics.dispose();

    await tester.tap(find.bySemanticsLabel('notifications.dismiss'.tr()));
    await tester.pumpAndSettle();
    expect(notices.current, isNull);
    expect(find.text(noAccount.title), findsNothing);
  });

  testWidgets('sits below the status bar, at the top', (
    WidgetTester tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 120);
    addTearDown(tester.view.reset);
    await pumpHost(tester);
    notices.show(noAccount);
    await tester.pumpAndSettle();

    final Rect card = tester.getRect(find.byType(NotificationCard));
    final double topInset = 120 / tester.view.devicePixelRatio;
    expect(card.top, greaterThanOrEqualTo(topInset));
    expect(card.top, lessThan(topInset + 40));
  });

  testWidgets('leaves on its own after its duration', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    notices.show(noAccount);
    await tester.pump();

    await tester.pump(AppDurations.noticeLong - const Duration(seconds: 1));
    expect(notices.current, isNotNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(notices.current, isNull);
  });

  testWidgets('showing it again restarts the clock, and draws one card', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    notices.show(noAccount);
    await tester.pump(AppDurations.noticeLong - const Duration(seconds: 1));
    notices.show(noAccount);
    await tester.pump(const Duration(seconds: 2));

    expect(notices.current, isNotNull);
    expect(find.byType(NotificationCard), findsOneWidget);
    await tester.pump(AppDurations.noticeLong);
    await tester.pumpAndSettle();
  });

  testWidgets('with TalkBack on it stays until dismissed', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpHost(tester);
    notices.show(noAccount);
    await tester.pump(AppDurations.noticeLong * 3);
    expect(notices.current, isNotNull);
    notices.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('in Arabic the icon leads from the right', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester, locale: AppLocales.arabic, dark: true);
    notices.show(noAccount);
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(NotificationCard))),
      TextDirection.rtl,
    );
    final Rect icon = tester.getRect(
      find.byIcon(NotificationCard.icon(AppNotificationKind.error)),
    );
    final Rect close = tester.getRect(find.byIcon(Icons.close_rounded));
    expect(icon.center.dx, greaterThan(close.center.dx));
    notices.dismiss();
    await tester.pumpAndSettle();
  });
}
