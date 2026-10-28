import 'package:flutter/material.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Shortcuts for the values every widget reaches for, so widget code is not
/// full of `Theme.of(context)` / `MediaQuery.of(context)`.
extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The palette roles of the active theme — light or dark, whichever is on
  /// screen. Read through `Theme.of`, so a widget rebuilds when it switches.
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;

  TextTheme get texts => Theme.of(this).textTheme;

  /// True when the active locale lays out right-to-left (Arabic).
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  /// +1 in a left-to-right layout, −1 in a right-to-left one: multiply a
  /// physical x distance by it to make it point toward the reading
  /// direction's end side.
  double get directionSign => isRtl ? -1 : 1;

  /// True when the user asked the system to remove animations. Every motion
  /// primitive checks it itself and shows its final state on the first frame.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// True while the dark theme is on screen — whether chosen or followed from
  /// the system.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
