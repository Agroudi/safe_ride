import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status and navigation bar styling that follows the active theme.
///
/// Both bars are transparent so the app's background runs behind them; only
/// the icon brightness changes — dark icons on the light theme, light icons on
/// the dark one. Placed in `MaterialApp.builder`, so it sits under every route
/// and re-reads the brightness the moment the theme switches.
class SystemBars extends StatelessWidget {
  const SystemBars({required this.child, super.key});

  final Widget child;

  /// The bars for a theme of [brightness].
  static SystemUiOverlayStyle styleFor(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Brightness icons = dark ? Brightness.light : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: icons,
      systemNavigationBarIconBrightness: icons,
      // iOS reads the opposite flag: the brightness of what is behind it.
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// The bars for [mode] before any theme exists, `system` resolved against
  /// the device. `main` sets this once: the region below only takes effect
  /// after the first frames, which a dark app would otherwise open under the
  /// window's dark status icons.
  static SystemUiOverlayStyle styleForMode(ThemeMode mode) {
    return styleFor(switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: styleFor(Theme.of(context).brightness),
      child: child,
    );
  }
}
