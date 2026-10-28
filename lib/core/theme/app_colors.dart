import 'package:flutter/material.dart';

/// The palette, as a theme extension with one instance per brightness.
///
/// The names are **roles**, not colours, so no widget changes when the brand
/// does and every widget recolours on its own in dark mode. Widgets read
/// `context.appColors.<role>`; never put a `Color(0x…)` literal anywhere else —
/// add a role here instead.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.accentText,
    required this.launchTile,
    required this.onLaunchTile,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.onStatus,
    required this.tintOpacity,
  });

  static const AppColors light = AppColors(
    primary: Color(0xFF142B4A), // Deep Navy
    onPrimary: Color(0xFFFFFFFF), // White (on primary)
    primaryContainer: Color(0xFF1E4268), // Navy Blue (primary variant)
    onPrimaryContainer: Color(0xFFFFFFFF), // White
    secondary: Color(0xFF0D9488), // Teal
    onSecondary: Color(0xFFFFFFFF), // White
    accentText: Color(0xFF0F766E), // Deep Teal (5.19:1 on Cool White)
    launchTile: Color(0xFF142B4A), // = ic_launcher_background
    onLaunchTile: Color(0xFFFFFFFF), // = ic_launcher_foreground's fill
    background: Color(0xFFF7F9FC), // Cool White
    surface: Color(0xFFFFFFFF), // White
    surfaceElevated: Color(0xFFFFFFFF), // White (no elevation tone in light)
    text: Color(0xFF172B4D), // Midnight
    textMuted: Color(0xFF64748B), // Slate
    border: Color(0xFFE2E8F0), // Soft Gray
    success: Color(0xFF15803D), // Emerald
    warning: Color(0xFFD97706), // Amber
    error: Color(0xFFDC2626), // Crimson
    info: Color(0xFF2563EB), // Blue
    onStatus: Color(0xFFFFFFFF), // White
    tintOpacity: 0.10,
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF8CB9F4), // Light Blue
    onPrimary: Color(0xFF0B1220), // Deep Midnight (on primary)
    primaryContainer: Color(0xFF1B3453), // Deep Navy (primary container)
    onPrimaryContainer: Color(0xFFF1F5F9), // Off-White
    secondary: Color(0xFF5EEAD4), // Light Teal
    onSecondary: Color(0xFF0B1220), // Deep Midnight
    accentText: Color(0xFF5EEAD4), // Light Teal (= secondary)
    launchTile: Color(0xFF142B4A), // = ic_launcher_background
    onLaunchTile: Color(0xFFFFFFFF), // = ic_launcher_foreground's fill
    background: Color(0xFF0B1220), // Deep Midnight
    surface: Color(0xFF151F30), // Dark Slate
    surfaceElevated: Color(0xFF1D293B), // Lighter Slate
    text: Color(0xFFF1F5F9), // Off-White
    textMuted: Color(0xFFA6B4C7), // Muted Slate
    border: Color(0xFF2A394D), // Dark Border
    success: Color(0xFF4ADE80), // Light Emerald
    warning: Color(0xFFFBBF24), // Light Amber
    error: Color(0xFFF87171), // Light Red
    info: Color(0xFF60A5FA), // Light Blue (information)
    onStatus: Color(0xFF0B1220), // Deep Midnight
    tintOpacity: 0.18,
  );

  // Brand
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Links, focus rings and accents.
  final Color secondary;
  final Color onSecondary;

  /// Teal for small text — eyebrows, text links. [secondary] is for fills,
  /// rules and icons; it is below 4.5:1 as small text on the light
  /// background.
  final Color accentText;

  // Launch hand-off
  /// The launcher icon's tile, which the system splash draws. Same value as
  /// `ic_launcher_background` in `res/values/colors.xml`; change both
  /// together (`brand_mark_test` compares them).
  final Color launchTile;

  /// The mark on [launchTile], as `ic_launcher_foreground.xml` draws it.
  final Color onLaunchTile;

  // Surfaces and lines
  /// The scaffold.
  final Color background;

  /// Cards, fields and tiles.
  final Color surface;

  /// Sheets and raised cards — one step above [surface] in dark mode.
  final Color surfaceElevated;

  /// Borders and dividers.
  final Color border;

  // Text
  /// Headings and body alike.
  final Color text;

  /// Secondary text, hints and field labels.
  final Color textMuted;

  // Feedback
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Text and icons on a solid [success] / [warning] / [error] / [info] fill.
  final Color onStatus;

  /// How strongly [tint] washes a role over the surface. Dark surfaces need a
  /// stronger wash to read as tinted at all.
  final double tintOpacity;

  /// An opaque, quiet wash of [color] over [surface] — icon badges,
  /// illustration panels, selected rows. Opaque so a tile never shows what is
  /// behind it.
  Color tint(Color color) =>
      Color.alphaBlend(color.withValues(alpha: tintOpacity), surface);

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? accentText,
    Color? launchTile,
    Color? onLaunchTile,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? text,
    Color? textMuted,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? onStatus,
    double? tintOpacity,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      accentText: accentText ?? this.accentText,
      launchTile: launchTile ?? this.launchTile,
      onLaunchTile: onLaunchTile ?? this.onLaunchTile,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      onStatus: onStatus ?? this.onStatus,
      tintOpacity: tintOpacity ?? this.tintOpacity,
    );
  }

  /// Blends every role, so a theme switch animates instead of snapping.
  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppColors(
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      secondary: mix(secondary, other.secondary),
      onSecondary: mix(onSecondary, other.onSecondary),
      accentText: mix(accentText, other.accentText),
      launchTile: mix(launchTile, other.launchTile),
      onLaunchTile: mix(onLaunchTile, other.onLaunchTile),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      border: mix(border, other.border),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      info: mix(info, other.info),
      onStatus: mix(onStatus, other.onStatus),
      tintOpacity: tintOpacity + (other.tintOpacity - tintOpacity) * t,
    );
  }
}
