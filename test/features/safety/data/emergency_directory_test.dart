import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/features/safety/data/models/emergency_directory.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';

/// Serves the real dataset file, as the app would read it offline.
class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    utf8.encode(File(EmergencyDataSource.asset).readAsStringSync()),
  );
}

const EmergencyServiceType _ambulance = EmergencyServiceType.ambulance;
const EmergencyServiceType _police = EmergencyServiceType.police;
const EmergencyServiceType _fire = EmergencyServiceType.fire;
const EmergencyServiceType _traffic = EmergencyServiceType.traffic;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EmergencyRepository repository;

  setUp(
    () => repository = BundledEmergencyRepository(
      EmergencyDataSource(bundle: _Bundle()),
    ),
  );

  Future<EmergencyDirectory> directory(String code) async =>
      EmergencyDirectory.of((await repository.forCountry(code))!);

  /// What each country's directory must say, per essential service — the
  /// published numbers, checked 2026-11-08. Null: no checked number of its
  /// own, said out loud rather than guessed.
  const Map<String, Map<EmergencyServiceType, String?>> expected =
      <String, Map<EmergencyServiceType, String?>>{
        'SA': <EmergencyServiceType, String?>{
          _ambulance: '997',
          _police: '999',
          _fire: '998',
          _traffic: '993',
        },
        'AE': <EmergencyServiceType, String?>{
          _ambulance: '998',
          _police: '999',
          _fire: '997',
          _traffic: null,
        },
        'KW': <EmergencyServiceType, String?>{
          _ambulance: '112',
          _police: '112',
          _fire: '112',
          _traffic: null,
        },
        'QA': <EmergencyServiceType, String?>{
          _ambulance: '999',
          _police: '999',
          _fire: '999',
          _traffic: null,
        },
        'BH': <EmergencyServiceType, String?>{
          _ambulance: '999',
          _police: '999',
          _fire: '999',
          _traffic: '199',
        },
        'OM': <EmergencyServiceType, String?>{
          _ambulance: '9999',
          _police: '9999',
          _fire: '9999',
          _traffic: null,
        },
        'EG': <EmergencyServiceType, String?>{
          _ambulance: '123',
          _police: '122',
          _fire: '180',
          _traffic: '01221110000',
        },
      };

  test('every supported country has a directory', () async {
    for (final Country c in Countries.supported) {
      expect(expected.keys, contains(c.code));
      expect(await repository.forCountry(c.code), isNotNull, reason: c.code);
    }
  });

  for (final MapEntry<String, Map<EmergencyServiceType, String?>> country
      in expected.entries) {
    test('${country.key}: the right number for every service, offline, '
        'and what is missing said', () async {
      final EmergencyDirectory d = await directory(country.key);
      country.value.forEach((EmergencyServiceType type, String? number) {
        if (number == null) {
          expect(d.missing, contains(type), reason: '$type');
          expect(
            d.numberFor(type)?.types,
            anyOf(isNull, contains(EmergencyServiceType.general)),
            reason: 'never another service standing in for $type',
          );
        } else {
          expect(d.numberFor(type)?.number, number, reason: '$type');
          expect(d.missing, isNot(contains(type)));
        }
      });
      // Every number once.
      expect(
        d.lines.map((DirectoryLine l) => l.service.number).toSet().length,
        d.lines.length,
      );
    });
  }

  group('ordered by what happened', () {
    test('Saudi Arabia: 911 first and named regional; then ambulance, '
        'police, civil defence, traffic, road security', () async {
      final EmergencyDirectory d = await directory('SA');
      expect(d.lines.map((DirectoryLine l) => l.service.number), <String>[
        '911',
        '997',
        '999',
        '998',
        '993',
        '996',
      ]);
      expect(d.regional.single.service.number, '911');
      expect(d.regional.single.regional, isTrue);
      expect(d.regional.single.service.note?.en, contains('Riyadh'));
      expect(d.national.every((DirectoryLine l) => !l.regional), isTrue);
    });

    test('a shared number names its services in the directory order', () async {
      final DirectoryLine kw = (await directory('KW')).lines.single;
      expect(kw.types, <EmergencyServiceType>[_ambulance, _police, _fire]);
      expect(kw.unified, isTrue);
    });

    test('Egypt: ambulance first, the traffic line last', () async {
      final EmergencyDirectory d = await directory('EG');
      expect(d.lines.map((DirectoryLine l) => l.service.number), <String>[
        '123',
        '122',
        '180',
        '01221110000',
      ]);
    });
  });

  group('regional numbers', () {
    EmergencyCountry country(List<EmergencyService> services) =>
        EmergencyCountry(
          code: 'SA',
          checkedOn: DateTime.utc(2026, 11, 8),
          services: services,
          sources: const <EmergencySource>[],
        );
    const LocalizedText where = LocalizedText(en: 'North only', ar: 'الشمال');

    test('never stand in for a national number', () {
      final EmergencyDirectory d = EmergencyDirectory.of(
        country(const <EmergencyService>[
          EmergencyService(
            types: <EmergencyServiceType>[EmergencyServiceType.general],
            number: '911',
            verification: Verification.official,
            sourceIds: <String>['s'],
            note: where,
            regional: true,
          ),
          EmergencyService(
            types: <EmergencyServiceType>[_police],
            number: '999',
            verification: Verification.official,
            sourceIds: <String>['s'],
          ),
        ]),
      );
      expect(d.numberFor(_police)?.number, '999');
      expect(d.numberFor(_ambulance), isNull);
      expect(d.missing, <EmergencyServiceType>[_ambulance, _fire, _traffic]);
    });

    test('a national number for every emergency covers a missing service', () {
      final EmergencyDirectory d = EmergencyDirectory.of(
        country(const <EmergencyService>[
          EmergencyService(
            types: <EmergencyServiceType>[EmergencyServiceType.general],
            number: '112',
            verification: Verification.official,
            sourceIds: <String>['s'],
          ),
        ]),
      );
      expect(d.numberFor(_fire)?.number, '112');
      expect(d.missing, isEmpty);
      expect(d.lines.single.unified, isTrue);
    });
  });

  group('the dataset says where a regional number works', () {
    Map<String, Object?> entry(Map<String, Object?> service) =>
        <String, Object?>{
          'code': 'SA',
          'checkedOn': '2026-11-08',
          'services': <Object?>[service],
          'sources': <Object?>[
            <String, Object?>{
              'id': 's',
              'publisher': <String, String>{'en': 'CST', 'ar': 'الهيئة'},
              'url': 'https://www.cst.gov.sa/',
            },
          ],
        };
    Map<String, Object?> service({Object? scope, bool note = true}) =>
        <String, Object?>{
          'types': <String>['general'],
          'number': '911',
          'verification': 'official',
          'sources': <String>['s'],
          'scope': ?scope,
          if (note)
            'note': <String, String>{'en': 'Some regions', 'ar': 'بعض المناطق'},
        };

    test('a regional number with its regions is read', () {
      final EmergencyCountry? c = EmergencyDataSource.parse(
        entry(service(scope: 'regional')),
      );
      expect(c?.services.single.regional, isTrue);
    });

    test('national is the default', () {
      expect(
        EmergencyDataSource.parse(entry(service()))?.services.single.regional,
        isFalse,
      );
    });

    test('a regional number that does not name its regions is left out', () {
      expect(
        EmergencyDataSource.parse(
          entry(service(scope: 'regional', note: false)),
        ),
        isNull,
      );
    });

    test('an unknown scope is left out', () {
      expect(EmergencyDataSource.parse(entry(service(scope: 'city'))), isNull);
    });
  });

  group('the bundled dataset, re-checked 2026-11-08', () {
    late Map<String, Object?> raw;

    setUpAll(() {
      raw =
          jsonDecode(File(EmergencyDataSource.asset).readAsStringSync())
              as Map<String, Object?>;
    });

    test('every country was re-checked on 2026-11-08', () async {
      for (final Country c in Countries.supported) {
        expect(
          (await repository.forCountry(c.code))!.checkedOn,
          DateTime.utc(2026, 11, 8),
        );
      }
    });

    test("Saudi Arabia's 911 is regional, and the country note says SafeRide "
        "can't tell the region", () async {
      final EmergencyCountry sa = (await repository.forCountry('SA'))!;
      expect(
        sa.services
            .where((EmergencyService s) => s.regional)
            .map((EmergencyService s) => s.number),
        <String>['911'],
      );
      expect(sa.note?.en, contains("can't tell which region"));
    });

    test('no source is a page that does not show what it is cited for', () {
      final String text = jsonEncode(raw);
      // These Saudi Press Agency pages showed only unrelated headlines.
      for (final String gone in <String>['N2525906', 'N2517952', 'N2554935']) {
        expect(text, isNot(contains(gone)));
      }
    });

    test('numbers left out as unverified stay out', () async {
      for (final (String code, String number) in <(String, String)>[
        ('SA', '112'),
        ('EG', '112'),
        ('AE', '112'),
        ('BH', '112'),
        ('OM', '999'),
      ]) {
        final EmergencyCountry c = (await repository.forCountry(code))!;
        expect(
          c.services.map((EmergencyService s) => s.number),
          isNot(contains(number)),
          reason: '$code $number',
        );
      }
    });
  });
}
