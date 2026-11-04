import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';

/// Serves [text] as the dataset.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.text);

  final String text;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(text));
}

Map<String, Object?> _entry({
  String code = 'QA',
  Object? services,
  Object? sources,
}) => <String, Object?>{
  'code': code,
  'checkedOn': '2026-11-03',
  'services':
      services ??
      <Object?>[
        <String, Object?>{
          'types': <String>['police', 'ambulance', 'fire'],
          'number': '999',
          'verification': 'official',
          'sources': <String>['moi'],
        },
      ],
  'sources':
      sources ??
      <Object?>[
        <String, Object?>{
          'id': 'moi',
          'publisher': <String, String>{'en': 'MOI', 'ar': 'الداخلية'},
          'url': 'https://portal.moi.gov.qa/',
        },
      ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled dataset', () {
    late Map<String, Object?> raw;
    late Map<String, EmergencyCountry> loaded;

    setUpAll(() async {
      raw =
          jsonDecode(File(EmergencyDataSource.asset).readAsStringSync())
              as Map<String, Object?>;
      loaded = await EmergencyDataSource(
        bundle: _Bundle(File(EmergencyDataSource.asset).readAsStringSync()),
      ).load();
    });

    test('every entry is valid — none is dropped', () {
      expect(loaded, hasLength((raw['countries']! as List).length));
    });

    test('every supported country has official numbers', () {
      for (final Country c in Countries.supported) {
        final EmergencyCountry? numbers = loaded[c.code];
        expect(numbers, isNotNull, reason: c.code);
        expect(
          numbers!.services.where(
            (EmergencyService s) => s.verification == Verification.official,
          ),
          isNotEmpty,
          reason: c.code,
        );
        expect(numbers.checkedOn, DateTime.utc(2026, 11, 3));
        for (final EmergencyService s in numbers.services) {
          expect(UrlLauncherPhoneDialer.isDialable(s.number), isTrue);
        }
        for (final EmergencySource s in numbers.sources) {
          expect(s.url.scheme, 'https');
          expect(s.publisher.en, isNotEmpty);
          expect(s.publisher.ar, isNotEmpty);
        }
      }
    });

    test('police, ambulance and fire are reachable in every country', () {
      for (final EmergencyCountry c in loaded.values) {
        for (final EmergencyServiceType t in <EmergencyServiceType>[
          EmergencyServiceType.police,
          EmergencyServiceType.ambulance,
          EmergencyServiceType.fire,
        ]) {
          expect(c.serviceFor(t), isNotNull, reason: '${c.code} ${t.name}');
        }
      }
    });

    test('shared numbers are one service, as published', () {
      for (final (String code, String number) in <(String, String)>[
        ('QA', '999'),
        ('KW', '112'),
        ('BH', '999'),
        ('OM', '9999'),
      ]) {
        final EmergencyService s = loaded[code]!.serviceFor(
          EmergencyServiceType.police,
        )!;
        expect(s.number, number);
        expect(
          s.types,
          containsAll(<EmergencyServiceType>[
            EmergencyServiceType.ambulance,
            EmergencyServiceType.fire,
          ]),
        );
      }
      final EmergencyCountry sa = loaded['SA']!;
      expect(sa.serviceFor(EmergencyServiceType.general)?.number, '911');
      expect(sa.serviceFor(EmergencyServiceType.police)?.number, '999');
      expect(sa.note, isNotNull);
      final EmergencyCountry eg = loaded['EG']!;
      expect(eg.serviceFor(EmergencyServiceType.general), isNull);
      expect(eg.serviceFor(EmergencyServiceType.ambulance)?.number, '123');
    });
  });

  group('a bad entry is left out whole', () {
    test('a valid entry is read', () {
      expect(EmergencyDataSource.parse(_entry())?.code, 'QA');
    });

    for (final (String why, Map<String, Object?> entry)
        in <(String, Map<String, Object?>)>[
          ('a lower-case code', _entry(code: 'qa')),
          (
            'a number with letters',
            _entry(
              services: <Object?>[
                <String, Object?>{
                  'types': <String>['police'],
                  'number': '99A',
                  'verification': 'official',
                  'sources': <String>['moi'],
                },
              ],
            ),
          ),
          (
            'no number at all',
            _entry(
              services: <Object?>[
                <String, Object?>{
                  'types': <String>['police'],
                  'verification': 'official',
                  'sources': <String>['moi'],
                },
              ],
            ),
          ),
          (
            'an unknown service',
            _entry(
              services: <Object?>[
                <String, Object?>{
                  'types': <String>['spaceForce'],
                  'number': '999',
                  'verification': 'official',
                  'sources': <String>['moi'],
                },
              ],
            ),
          ),
          (
            'an unverified number',
            _entry(
              services: <Object?>[
                <String, Object?>{
                  'types': <String>['police'],
                  'number': '112',
                  'verification': 'unverified',
                  'sources': <String>['moi'],
                },
              ],
            ),
          ),
          (
            'a service listed twice',
            _entry(
              services: <Object?>[
                <String, Object?>{
                  'types': <String>['police'],
                  'number': '999',
                  'verification': 'official',
                  'sources': <String>['moi'],
                },
                <String, Object?>{
                  'types': <String>['police'],
                  'number': '112',
                  'verification': 'official',
                  'sources': <String>['moi'],
                },
              ],
            ),
          ),
          (
            'a source the country does not list',
            _entry(
              services: <Object?>[
                <String, Object?>{
                  'types': <String>['police'],
                  'number': '999',
                  'verification': 'official',
                  'sources': <String>['blog'],
                },
              ],
            ),
          ),
          ('no sources', _entry(sources: <Object?>[])),
          (
            'a plain-http source',
            _entry(
              sources: <Object?>[
                <String, Object?>{
                  'id': 'moi',
                  'publisher': <String, String>{'en': 'MOI', 'ar': 'الداخلية'},
                  'url': 'http://portal.moi.gov.qa/',
                },
              ],
            ),
          ),
          (
            'a publisher missing its Arabic',
            _entry(
              sources: <Object?>[
                <String, Object?>{
                  'id': 'moi',
                  'publisher': <String, String>{'en': 'MOI', 'ar': ' '},
                  'url': 'https://portal.moi.gov.qa/',
                },
              ],
            ),
          ),
        ]) {
      test(why, () => expect(EmergencyDataSource.parse(entry), isNull));
    }

    test('one broken country never hides the others', () async {
      final Map<String, EmergencyCountry> loaded = await EmergencyDataSource(
        bundle: _Bundle(
          jsonEncode(<String, Object?>{
            'countries': <Object?>[_entry(), _entry(code: 'kw')],
          }),
        ),
      ).load();
      expect(loaded.keys, <String>['QA']);
    });

    test('a damaged file gives no numbers rather than wrong ones', () async {
      expect(
        await EmergencyDataSource(bundle: _Bundle('{"countries": [')).load(),
        isEmpty,
      );
    });
  });

  test('the repository reads the dataset once', () async {
    int reads = 0;
    final EmergencyRepository repo = BundledEmergencyRepository(
      _CountingSource(() => reads++),
    );
    expect((await repo.forCountry('QA'))?.code, 'QA');
    expect(await repo.forCountry('US'), isNull);
    expect(reads, 1);
  });

  group('which numbers are handed to the phone app', () {
    test('digits, two to fifteen, an optional leading +', () {
      for (final String ok in <String>[
        '911',
        '9999',
        '01221110000',
        '+97499',
      ]) {
        expect(UrlLauncherPhoneDialer.isDialable(ok), isTrue, reason: ok);
      }
      for (final String bad in <String>[
        '',
        '9',
        '99A',
        '999 ',
        '*99#',
        '1234567890123456',
        'tel:999',
      ]) {
        expect(UrlLauncherPhoneDialer.isDialable(bad), isFalse, reason: bad);
      }
    });

    test('an invalid number never reaches the phone app', () async {
      expect(
        await const UrlLauncherPhoneDialer().open('99A'),
        DialOutcome.invalidNumber,
      );
    });
  });
}

class _CountingSource extends EmergencyDataSource {
  _CountingSource(this._read) : super(bundle: _Bundle(''));

  final void Function() _read;

  @override
  Future<Map<String, EmergencyCountry>> load() async {
    _read();
    return <String, EmergencyCountry>{
      'QA': EmergencyDataSource.parse(_entry())!,
    };
  }
}
