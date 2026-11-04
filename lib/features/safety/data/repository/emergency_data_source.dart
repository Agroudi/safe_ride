import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';

/// Reads the emergency numbers bundled with the app
/// (`assets/data/emergency_services.json`). They ship inside the app, so
/// they work offline from the first launch and never wait on the network.
///
/// **Every entry is checked before it is used** (a two-letter code; digits
/// only; known service types, each once; an official or secondary source
/// that the country lists; a check date). A country whose entry fails any
/// check is left out whole — never shown half-right — and the screen says
/// its numbers are unavailable. `emergency_data_source_test` fails the
/// build on any invalid entry, so a bad edit cannot ship.
class EmergencyDataSource {
  EmergencyDataSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String asset = 'assets/data/emergency_services.json';

  final AssetBundle _bundle;

  /// The valid countries by code.
  Future<Map<String, EmergencyCountry>> load() async {
    final Object? document;
    try {
      document = jsonDecode(await _bundle.loadString(asset));
    } on Object {
      return const <String, EmergencyCountry>{};
    }
    final Object? list = document is Map ? document['countries'] : null;
    if (list is! List) return const <String, EmergencyCountry>{};
    final Map<String, EmergencyCountry> valid = <String, EmergencyCountry>{};
    for (final Object? entry in list) {
      final EmergencyCountry? country = parse(entry);
      if (country != null && !valid.containsKey(country.code)) {
        valid[country.code] = country;
      }
    }
    return valid;
  }

  static final RegExp _code = RegExp(r'^[A-Z]{2}$');
  static final RegExp _digits = RegExp(r'^[0-9]{2,15}$');

  /// One country entry, or null when anything in it is wrong.
  static EmergencyCountry? parse(Object? json) {
    try {
      final Map<String, Object?> m = (json! as Map).cast<String, Object?>();
      final String code = m['code']! as String;
      final DateTime checkedOn = DateTime.parse(m['checkedOn']! as String);
      final List<EmergencySource> sources = <EmergencySource>[
        for (final Object? s in m['sources']! as List) _source(s),
      ];
      final Set<String> sourceIds = sources.map((s) => s.id).toSet();
      final List<EmergencyService> services = <EmergencyService>[
        for (final Object? s in m['services']! as List) _service(s),
      ];
      final List<EmergencyServiceType> types = <EmergencyServiceType>[
        for (final EmergencyService s in services) ...s.types,
      ];
      final bool ok =
          _code.hasMatch(code) &&
          sources.isNotEmpty &&
          sourceIds.length == sources.length &&
          services.isNotEmpty &&
          types.toSet().length == types.length &&
          services.every(
            (EmergencyService s) =>
                _digits.hasMatch(s.number) &&
                s.types.isNotEmpty &&
                s.sourceIds.isNotEmpty &&
                s.sourceIds.every(sourceIds.contains),
          );
      if (!ok) return null;
      return EmergencyCountry(
        code: code,
        checkedOn: DateTime.utc(checkedOn.year, checkedOn.month, checkedOn.day),
        services: services,
        sources: sources,
        note: _text(m['note']),
      );
    } on Object {
      return null;
    }
  }

  static EmergencySource _source(Object? json) {
    final Map<String, Object?> m = (json! as Map).cast<String, Object?>();
    final Uri url = Uri.parse(m['url']! as String);
    if (url.scheme != 'https') throw const FormatException('https only');
    return EmergencySource(
      id: m['id']! as String,
      publisher: _text(m['publisher'])!,
      url: url,
    );
  }

  static EmergencyService _service(Object? json) {
    final Map<String, Object?> m = (json! as Map).cast<String, Object?>();
    return EmergencyService(
      types: <EmergencyServiceType>[
        for (final Object? t in m['types']! as List)
          EmergencyServiceType.values.byName(t! as String),
      ],
      number: m['number']! as String,
      verification: Verification.values.byName(m['verification']! as String),
      sourceIds: <String>[
        for (final Object? id in m['sources']! as List) id! as String,
      ],
      note: _text(m['note']),
    );
  }

  static LocalizedText? _text(Object? json) {
    if (json == null) return null;
    final Map<String, Object?> m = (json as Map).cast<String, Object?>();
    final String en = m['en']! as String;
    final String ar = m['ar']! as String;
    if (en.trim().isEmpty || ar.trim().isEmpty) {
      throw const FormatException('empty text');
    }
    return LocalizedText(en: en, ar: ar);
  }
}
