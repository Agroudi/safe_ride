import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/core/theme/app_text_theme.dart';

/// Single source of truth for the look and feel.
///
/// [light] and [dark] are one recipe fed two palettes, so a component themed
/// here can never look right in one brightness and forgotten in the other.
/// The scheme is written out **explicitly**, not seeded: a seed generates
/// colours the design never chose.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final TextTheme text = AppTextTheme.of(colors);
    final ColorScheme scheme = _scheme(colors, brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[colors],
      scaffoldBackgroundColor: colors.background,
      focusColor: colors.primary.withValues(alpha: 0.12),
      hoverColor: colors.primary.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge,
      ),
      // Every text field in the app gets this; `AppTextField` only adds the
      // label above it and the eye inside it.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        hintStyle: text.bodyMedium?.copyWith(color: colors.textMuted),
        errorStyle: text.labelSmall?.copyWith(color: colors.error),
        helperStyle: text.labelSmall?.copyWith(color: colors.textMuted),
        errorMaxLines: 2,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 17.fx,
          vertical: 15.fx,
        ),
        border: _border(colors.border),
        enabledBorder: _border(colors.border),
        focusedBorder: _border(colors.secondary),
        errorBorder: _border(colors.error),
        focusedErrorBorder: _border(colors.error),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        modalBackgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      // The sign-out confirmation (`showAppConfirmDialog`).
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(color: colors.text),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.textMuted,
          height: 1.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.secondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.secondary,
        selectionColor: colors.secondary.withValues(alpha: 0.3),
        selectionHandleColor: colors.secondary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.textMuted),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
    );
  }

  static ColorScheme _scheme(AppColors colors, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      secondaryContainer: colors.tint(colors.secondary),
      onSecondaryContainer: colors.text,
      tertiary: colors.info,
      onTertiary: colors.onStatus,
      error: colors.error,
      onError: colors.onStatus,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.textMuted,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.surface,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceElevated,
      surfaceContainerHighest: colors.surfaceElevated,
      surfaceTint: Colors.transparent,
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: colors.text,
      onInverseSurface: colors.background,
      // The other palette's primary is the one designed to sit on this
      // palette's inverse surface.
      inversePrimary: brightness == Brightness.light
          ? AppColors.dark.primary
          : AppColors.light.primary,
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16.fx),
    borderSide: BorderSide(color: color, width: 1.fx),
  );
}
