import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// How a journey reads on screen — the same words, colours and dates on
/// home, My Journeys and the details screen.
abstract final class JourneyLabels {
  static String status(BuildContext context, JourneyStatus status) =>
      context.tr('journeys.status.${status.name}');

  /// Planned is information (still open), completed a success, cancelled
  /// quiet. The chip always carries the word too — never colour alone.
  static Color tone(AppColors colors, JourneyStatus status) => switch (status) {
    JourneyStatus.planned => colors.info,
    JourneyStatus.completed => colors.success,
    JourneyStatus.cancelled => colors.textMuted,
  };

  /// Local time, in the locale's digits (`LocaleNumbers.dateTime`).
  static String date(BuildContext context, DateTime utc) =>
      LocaleNumbers.dateTime(context.locale.languageCode).format(utc.toLocal());

  /// When the journey leaves, or "departure not set" for one stored before
  /// departures existed — never a guess.
  static String departure(BuildContext context, DateTime? utc) =>
      utc == null ? context.tr('journeys.departureNotSet') : date(context, utc);

  /// A place typed by the user, in a first-strong isolate (U+2068 … U+2069):
  /// a Latin address inside an Arabic sentence, or the reverse, keeps its
  /// own order (CLAUDE.md §8).
  static String place(String value) =>
      '${String.fromCharCode(0x2068)}$value${String.fromCharCode(0x2069)}';

  /// "Home to Work", for a screen reader reading a whole tile.
  static String route(BuildContext context, JourneyModel journey) => context.tr(
    'journeys.route',
    namedArgs: <String, String>{
      'from': place(journey.origin),
      'to': place(journey.destination),
    },
  );
}
