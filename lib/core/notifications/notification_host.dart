import 'dart:async';

import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/notifications/notification_card.dart';

/// Draws [AppNotifier.current] over every route, from `MaterialApp.builder`.
///
/// - **Where:** at the top, under the status bar — clear of the keyboard and
///   of the buttons at the bottom of every screen; never wider than
///   [maxWidth]. Only the card takes touches; the rest of the screen works.
/// - **How long:** the notification's own duration, restarted each time the
///   same message is shown again; with TalkBack on (accessible navigation)
///   nothing leaves on its own — it stays until dismissed.
/// - **Motion:** drops in 12 and fades on `AppCurves.enter`, leaves on
///   `exit`; a cut under reduced motion.
class NotificationHost extends StatefulWidget {
  const NotificationHost({
    required this.notifier,
    required this.child,
    super.key,
  });

  final AppNotifier notifier;
  final Widget child;

  static const double maxWidth = 520;

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_changed);
  }

  @override
  void didUpdateWidget(NotificationHost old) {
    super.didUpdateWidget(old);
    if (old.notifier == widget.notifier) return;
    old.notifier.removeListener(_changed);
    widget.notifier.addListener(_changed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.notifier.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _timer?.cancel();
    final AppNotification? on = widget.notifier.current;
    final Duration? life = on?.duration;
    if (on != null &&
        life != null &&
        !MediaQuery.accessibleNavigationOf(context)) {
      _timer = Timer(life, () => widget.notifier.dismiss(id: on.id));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppNotification? on = widget.notifier.current;
    final bool still = context.reduceMotion;

    return Stack(
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenSide,
                8.fx,
                AppSpacing.screenSide,
                0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: NotificationHost.maxWidth,
                  ),
                  child: AnimatedSwitcher(
                    duration: still ? Duration.zero : AppDurations.medium,
                    reverseDuration: still ? Duration.zero : AppDurations.short,
                    switchInCurve: AppCurves.enter,
                    switchOutCurve: AppCurves.exit,
                    layoutBuilder: (Widget? current, List<Widget> previous) =>
                        Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[...previous, ?current],
                        ),
                    transitionBuilder: _drop,
                    child: on == null
                        ? const SizedBox.shrink()
                        : NotificationCard(
                            key: ValueKey<String>(on.id),
                            notification: on,
                            onDismiss: () => widget.notifier.dismiss(id: on.id),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _drop(Widget child, Animation<double> t) => FadeTransition(
    opacity: t,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.15),
        end: Offset.zero,
      ).animate(t),
      child: child,
    ),
  );
}
