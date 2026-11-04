import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/country/country.dart';

void main() {
  test('the seven countries, each once', () {
    expect(Countries.supported.map((Country c) => c.code).toSet(), <String>{
      'EG',
      'SA',
      'AE',
      'KW',
      'QA',
      'BH',
      'OM',
    });
    expect(Countries.supported, hasLength(7));
  });

  test('every country is named in Arabic and in English', () {
    for (final Country c in Countries.supported) {
      expect(c.nameEn, isNotEmpty);
      expect(c.nameAr, isNotEmpty);
      expect(c.nameAr, matches(RegExp(r'[؀-ۿ]')));
      expect(c.name('en'), c.nameEn);
      expect(c.name('ar'), c.nameAr);
    }
    expect(Countries.byCode('EG')!.name('ar'), 'مصر');
    expect(Countries.byCode('AE')!.name('en'), 'United Arab Emirates');
  });

  test('the flag is built from the code', () {
    expect(Countries.byCode('SA')!.flag, '🇸🇦');
    expect(Countries.byCode('EG')!.flag, '🇪🇬');
  });

  test('an unknown or missing code is no country', () {
    expect(Countries.byCode('US'), isNull);
    expect(Countries.byCode(null), isNull);
  });

  test('sorted by name in each language', () {
    expect(Countries.sorted('en').first.code, 'BH');
    // As written: the article «ال» sorts as its first letter.
    expect(Countries.sorted('ar').map((Country c) => c.code), <String>[
      'AE',
      'BH',
      'SA',
      'KW',
      'OM',
      'QA',
      'EG',
    ]);
  });
}
