import 'package:safe_ride/features/safety/data/models/emergency_services.dart';

/// One number in the directory and the services it answers, in the
/// directory's order.
final class DirectoryLine {
  const DirectoryLine(this.service, this.types);

  final EmergencyService service;

  /// What it answers, a number for every emergency first, then
  /// [EmergencyDirectory.order].
  final List<EmergencyServiceType> types;

  /// One number for several services (or for every emergency).
  bool get unified =>
      types.length > 1 || types.contains(EmergencyServiceType.general);

  /// Answers only in some regions ([EmergencyService.regional]).
  bool get regional => service.regional;
}

/// A country's checked numbers, arranged for someone looking for one in a
/// hurry: by what happened — a medical emergency, the police, fire and
/// rescue, a road accident, then the rest — never by how the dataset lists
/// them. Pure: built from an [EmergencyCountry], with no Flutter in it.
///
/// **Regional numbers never stand in for national ones.** SafeRide cannot
/// tell which region the user is in — GPS near a boundary, or old, would
/// pick wrongly — but the user knows. So a number that answers only in some
/// regions (Saudi Arabia's 911) comes first, with the regions it answers in,
/// and the national numbers follow; [numberFor] never returns a regional one.
final class EmergencyDirectory {
  const EmergencyDirectory._(
    this.country,
    this.regional,
    this.national,
    this.missing,
  );

  factory EmergencyDirectory.of(EmergencyCountry country) {
    List<EmergencyServiceType> ordered(EmergencyService s) =>
        <EmergencyServiceType>[...s.types]
          ..sort((a, b) => _rank(a).compareTo(_rank(b)));
    final List<DirectoryLine> national = <DirectoryLine>[
      for (final EmergencyService s in country.services)
        if (!s.regional) DirectoryLine(s, ordered(s)),
    ]..sort((a, b) => _rank(a.types.first).compareTo(_rank(b.types.first)));
    final List<DirectoryLine> regional = <DirectoryLine>[
      for (final EmergencyService s in country.services)
        if (s.regional) DirectoryLine(s, ordered(s)),
    ];
    final List<EmergencyServiceType> missing = <EmergencyServiceType>[
      for (final EmergencyServiceType t in essential)
        if (_national(country, t) == null) t,
    ];
    return EmergencyDirectory._(country, regional, national, missing);
  }

  /// What someone needs most often, first.
  static const List<EmergencyServiceType> order = <EmergencyServiceType>[
    EmergencyServiceType.ambulance,
    EmergencyServiceType.police,
    EmergencyServiceType.fire,
    EmergencyServiceType.traffic,
    EmergencyServiceType.roadSecurity,
  ];

  /// The services whose absence the directory says out loud.
  static const List<EmergencyServiceType> essential = <EmergencyServiceType>[
    EmergencyServiceType.ambulance,
    EmergencyServiceType.police,
    EmergencyServiceType.fire,
    EmergencyServiceType.traffic,
  ];

  final EmergencyCountry country;

  /// Numbers that answer only in some regions, as the dataset lists them.
  final List<DirectoryLine> regional;

  /// The rest, by their first service in [order]; a number for every
  /// emergency first.
  final List<DirectoryLine> national;

  /// Every number once, as shown: [regional], then [national].
  List<DirectoryLine> get lines => <DirectoryLine>[...regional, ...national];

  /// Essential services with no checked national number of their own.
  final List<EmergencyServiceType> missing;

  /// The national number for [type]: its own, else one for every
  /// emergency; null when the country has neither. Never a regional one.
  EmergencyService? numberFor(EmergencyServiceType type) =>
      _national(country, type);

  static EmergencyService? _national(
    EmergencyCountry country,
    EmergencyServiceType type,
  ) {
    EmergencyService? general;
    for (final EmergencyService s in country.services) {
      if (s.regional) continue;
      if (s.types.contains(type)) return s;
      if (s.types.contains(EmergencyServiceType.general)) general ??= s;
    }
    return general;
  }

  static int _rank(EmergencyServiceType type) =>
      type == EmergencyServiceType.general ? -1 : order.indexOf(type);
}
