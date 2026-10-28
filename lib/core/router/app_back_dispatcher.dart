import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';

/// Makes Android's back gesture mean **back** on every screen.
///
/// A screen reached with `context.go` has nothing to pop, and without this the
/// gesture falls straight through to the launcher — the app "closes from the
/// middle". The router is asked first; only when it popped nothing does this
/// decide where "up" is. It never returns `false`: returning `false` is what
/// closes the app.
///
/// ⚠️ Wire it through `MaterialApp.router(routerDelegate:, routeInformationParser:,
/// routeInformationProvider:, backButtonDispatcher:)` — **not** alongside
/// `routerConfig`. That combination is rejected by an `assert`, and asserts are
/// stripped from release builds, so it silently does nothing exactly where it
/// matters.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  AppBackButtonDispatcher({
    required this.router,
    required this.notifier,
    this.clock = DateTime.now,
  });

  final GoRouter router;

  /// Shows "press back again"; the dispatcher has no `BuildContext`.
  final AppNotifier notifier;

  /// Times the "press back again" window. The wall clock in the app; a test
  /// passes its own, so the window can expire without a real wait.
  final DateTime Function() clock;

  /// Where each dead end leads. Add a line when a new `go` target appears.
  /// Destinations take no path parameters — the ids went with the stack.
  static const Map<String, String> _up = <String, String>{
    AppRoutes.login: AppRoutes.welcome,
    AppRoutes.register: AppRoutes.welcome,
    AppRoutes.myJourneys: AppRoutes.home,
    AppRoutes.profile: AppRoutes.home,
    AppRoutes.planJourney: AppRoutes.home,
    AppRoutes.reviewJourney: AppRoutes.planJourney,
    AppRoutes.journey: AppRoutes.myJourneys,
    AppRoutes.editJourney: AppRoutes.myJourneys,
    AppRoutes.safety: AppRoutes.home,
    AppRoutes.trustedContacts: AppRoutes.safety,
    AppRoutes.addContact: AppRoutes.trustedContacts,
    AppRoutes.editContact: AppRoutes.trustedContacts,
    AppRoutes.safetyGuide: AppRoutes.safety,
    AppRoutes.journeySafety: AppRoutes.safety,
    AppRoutes.emergencyInfo: AppRoutes.safety,
    AppRoutes.editProfile: AppRoutes.profile,
    AppRoutes.settings: AppRoutes.profile,
    AppRoutes.about: AppRoutes.profile,
  };

  /// The ends of the road: the first back warns, a second one leaves.
  /// Welcome has no way back to onboarding — onboarding is done for good.
  static const Set<String> _exits = <String>{
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.welcome,
    AppRoutes.home,
  };

  /// The "press back again" notice's id: a second back inside the window
  /// leaves, and one outside it refreshes this notice rather than stacking.
  static const String exitNoticeId = 'app.exitConfirm';

  DateTime? _armed;

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;

    final String? name = _currentName();
    if (name == null || _exits.contains(name)) return _leaveOrWarn();

    // Marked as "up", so a pushed-style screen arrives with the neutral fade
    // and back never looks like forward.
    router.goNamed(_up[name] ?? AppRoutes.home, extra: AppPages.up);
    return true;
  }

  /// Read when the gesture arrives, never cached — `go` replaces the stack
  /// underneath, so a kept value names a screen that is no longer on top.
  String? _currentName() {
    try {
      return router.state.name;
    } on Object {
      return null; // Before the first route settles.
    }
  }

  Future<bool> _leaveOrWarn() async {
    final DateTime now = clock();
    final DateTime? armed = _armed;

    if (armed != null && now.difference(armed) <= AppDurations.exitWindow) {
      _armed = null;
      await SystemNavigator.pop();
      return true;
    }

    _armed = now;
    notifier.show(
      AppNotification(
        kind: AppNotificationKind.info,
        title: 'app.exitConfirm'.tr(),
        duration: AppDurations.exitWindow,
        id: exitNoticeId,
      ),
    );
    return true;
  }
}
