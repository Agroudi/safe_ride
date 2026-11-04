import 'package:equatable/equatable.dart';

/// A country SafeRide has emergency numbers for. Its names are data, in both
/// languages, so the list grows without touching the translation files.
final class Country extends Equatable {
  const Country({
    required this.code,
    required this.nameEn,
    required this.nameAr,
  });

  /// ISO 3166-1 alpha-2, upper case (`SA`).
  final String code;
  final String nameEn;
  final String nameAr;

  /// The name in [languageCode] (Arabic or English).
  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;

  /// The flag emoji, built from the code's regional-indicator letters.
  String get flag =>
      String.fromCharCodes(code.codeUnits.map((int c) => 0x1F1E6 + c - 0x41));

  @override
  List<Object?> get props => <Object?>[code];
}

/// Every supported country. A new one is a line here and an entry in
/// `assets/data/emergency_services.json` — nothing else.
abstract final class Countries {
  static const List<Country> supported = <Country>[
    Country(code: 'SA', nameEn: 'Saudi Arabia', nameAr: 'السعودية'),
    Country(code: 'AE', nameEn: 'United Arab Emirates', nameAr: 'الإمارات'),
    Country(code: 'KW', nameEn: 'Kuwait', nameAr: 'الكويت'),
    Country(code: 'QA', nameEn: 'Qatar', nameAr: 'قطر'),
    Country(code: 'BH', nameEn: 'Bahrain', nameAr: 'البحرين'),
    Country(code: 'OM', nameEn: 'Oman', nameAr: 'عُمان'),
    Country(code: 'EG', nameEn: 'Egypt', nameAr: 'مصر'),
  ];

  /// The supported country with [code], or null.
  static Country? byCode(String? code) {
    for (final Country c in supported) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// [supported], alphabetical in [languageCode].
  static List<Country> sorted(String languageCode) =>
      List<Country>.of(supported)..sort(
        (Country a, Country b) =>
            a.name(languageCode).compareTo(b.name(languageCode)),
      );
}
