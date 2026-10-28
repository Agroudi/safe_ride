import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_tab_bar.dart';

/// The signed-in frame: the four tabs' navigators and [AppTabBar].
///
/// Each tab keeps its own stack and scroll position (go_router's
/// `StatefulShellRoute`). Switching fades through on `AppDurations.short`;
/// only the shown tab ticks, and the outgoing one takes no taps. Tapping the
/// current tab again returns it to its first screen. Under reduced motion
/// the switch is a cut.
class AppTabShell extends StatelessWidget {
  const AppTabShell({required this.shell, required this.children, super.key});

  final StatefulNavigationShell shell;

  /// One navigator per branch, in [AppTabShell.items] order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _FadingTabs(index: shell.currentIndex, children: children),
      bottomNavigationBar: AppTabBar(
        current: shell.currentIndex,
        onSelected: (int i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: <AppTabItem>[
          AppTabItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: context.tr('tabs.home'),
          ),
          AppTabItem(
            icon: Icons.route_outlined,
            selectedIcon: Icons.route_rounded,
            label: context.tr('tabs.journeys'),
          ),
          AppTabItem(
            icon: Icons.health_and_safety_outlined,
            selectedIcon: Icons.health_and_safety_rounded,
            label: context.tr('tabs.safety'),
          ),
          AppTabItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: context.tr('tabs.profile'),
          ),
        ],
      ),
    );
  }
}

/// The branch navigators stacked in place — never re-parented, so none
/// loses its state — with the incoming one fading in over the outgoing.
class _FadingTabs extends StatefulWidget {
  const _FadingTabs({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadingTabs> createState() => _FadingTabsState();
}

class _FadingTabsState extends State<_FadingTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AppDurations.short,
    value: 1,
  );
  int? _leaving;

  @override
  void didUpdateWidget(_FadingTabs old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (context.reduceMotion) {
      _leaving = null;
      _fade.value = 1;
      return;
    }
    _leaving = old.index;
    _fade.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(() => _leaving = null);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> fadeIn = _fade.drive(
      CurveTween(curve: const Interval(AppMotion.fadeInStart, 1)),
    );
    final Animation<double> fadeOut = ReverseAnimation(
      _fade.drive(
        CurveTween(
          curve: const Interval(0, AppMotion.fadeOutEnd, curve: AppCurves.exit),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (int i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: i != widget.index && i != _leaving,
            child: TickerMode(
              enabled: i == widget.index,
              child: IgnorePointer(
                ignoring: i != widget.index,
                child: FadeTransition(
                  opacity: i == widget.index ? fadeIn : fadeOut,
                  child: widget.children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
