import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// Numbers, in the digits the design draws.
///
/// ⚠️ CLDR resolves both `ar` and `ar_SA` to **Latin** digits, so `NumberFormat`
/// in plain `ar` prints `8` beside an Arabic sentence. `ar_EG` is the Arabic
/// locale that still yields Arabic-Indic digits (`٨`), so it is used purely as
/// the numbering system. If a design uses Latin digits, delete the substitution
/// in [tag] and nothing else moves.
abstract final class LocaleNumbers {
  static String tag(String languageCode) =>
      languageCode == 'ar' ? 'ar_EG' : languageCode;

  /// The locale a Material date or time picker is given, so its grid and dial
  /// use the same digits as the rest of the screen (`ar_EG`, see [tag]).
  static Locale pickerLocale(String languageCode) {
    final List<String> parts = tag(languageCode).split('_');
    return Locale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  /// Whole numbers: counts, lengths, codes.
  static NumberFormat decimal(String languageCode) =>
      NumberFormat.decimalPattern(tag(languageCode));

  /// A date and time — "28 Oct 2026, 10:31" / «٢٨ أكتوبر ٢٠٢٦ ١٠:٣١ ص»,
  /// in the same digits. ⚠️ Needs `initializeDateFormatting()` (`main.dart`,
  /// `flutter_test_config.dart`): `ar_EG` is not one of the locales Flutter
  /// loads date symbols for.
  static DateFormat dateTime(String languageCode) =>
      DateFormat.yMMMd(tag(languageCode)).add_jm();
}
