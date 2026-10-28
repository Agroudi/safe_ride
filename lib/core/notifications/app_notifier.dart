import 'package:flutter/foundation.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';

/// The app's one notification channel: pages call [show] and [dismiss];
/// `NotificationHost` (above every route) draws [current].
///
/// **Policy — one at a time, newest wins.**
/// - A different notification replaces the one on screen; nothing queues
///   behind it, so a burst never plays out for seconds after its cause.
/// - The same notification ([AppNotification.id]) shown again does not
///   stack or re-animate: it refreshes the one on screen and restarts its
///   timer ([generation] changes, [current] keeps its identity).
///
/// A singleton in the service locator, with no `BuildContext`: the strings
/// arrive translated, and the host owns timing and animation.
class AppNotifier extends ChangeNotifier {
  AppNotification? _current;
  int _generation = 0;

  /// What is on screen, or null.
  AppNotification? get current => _current;

  /// Bumped by every [show] — the host restarts the timer when it changes.
  int get generation => _generation;

  void show(AppNotification notification) {
    final AppNotification? on = _current;
    // Same message again: keep the card, renew its time.
    _current = on != null && on.id == notification.id ? on : notification;
    _generation++;
    notifyListeners();
  }

  /// Hides the current notification — or only the one with [id], so a caller
  /// clearing its own message never closes someone else's.
  void dismiss({String? id}) {
    final AppNotification? on = _current;
    if (on == null || (id != null && on.id != id)) return;
    _current = null;
    notifyListeners();
  }
}
