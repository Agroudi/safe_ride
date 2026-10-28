import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The typography scale. Cairo covers Arabic and Latin, so one family serves
/// both locales. Sizes are the design's values, converted by `.fsp`.
///
/// Swap the family and sizes here per project — widgets only ever ask for a
/// role (`context.texts.titleLarge`) and adjust with `copyWith`. Colours come
/// from the [AppColors] passed in, so the same scale serves light and dark.
abstract final class AppTextTheme {
  static TextTheme of(AppColors colors) =>
      GoogleFonts.cairoTextTheme(_scale(colors));

  static TextTheme _scale(AppColors colors) => TextTheme(
    headlineMedium: TextStyle(
      fontSize: 23.fsp,
      fontWeight: FontWeight.w800,
      color: colors.text,
    ),
    titleLarge: TextStyle(
      fontSize: 18.fsp,
      fontWeight: FontWeight.w700,
      color: colors.text,
    ),
    titleMedium: TextStyle(
      fontSize: 16.fsp,
      fontWeight: FontWeight.w700,
      color: colors.text,
    ),
    // The primary call-to-action label.
    titleSmall: TextStyle(
      fontSize: 15.fsp,
      fontWeight: FontWeight.w700,
      color: colors.text,
    ),
    bodyMedium: TextStyle(
      fontSize: 14.fsp,
      fontWeight: FontWeight.w400,
      color: colors.text,
    ),
    bodySmall: TextStyle(
      fontSize: 13.fsp,
      fontWeight: FontWeight.w500,
      color: colors.textMuted,
    ),
    labelMedium: TextStyle(
      fontSize: 13.fsp,
      fontWeight: FontWeight.w600,
      color: colors.text,
    ),
    labelSmall: TextStyle(
      fontSize: 12.fsp,
      fontWeight: FontWeight.w400,
      color: colors.textMuted,
    ),
  );
}
