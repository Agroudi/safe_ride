import 'package:flutter/widgets.dart';

/// Locales the app ships with.
///
/// There is deliberately no start locale. easy_localization picks, in order:
/// the language the user chose (it saves `context.setLocale` itself), else the
/// device language when it is Arabic or English, else [fallback]. English is
/// also the fallback for a key missing from `ar.json`, so it shows in English
/// rather than as the raw key.
abstract final class AppLocales {
  static const Locale english = Locale('en');
  static const Locale arabic = Locale('ar');

  static const List<Locale> supported = <Locale>[english, arabic];
  static const Locale fallback = english;

  static const String translationsPath = 'assets/translations';
}
