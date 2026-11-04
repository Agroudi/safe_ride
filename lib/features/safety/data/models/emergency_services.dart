import 'package:equatable/equatable.dart';

/// What an emergency number is for. A country may answer several with one
/// number; an [EmergencyService] lists every type its number serves.
enum EmergencyServiceType {
  /// A unified number for every emergency.
  general,
  police,
  ambulance,

  /// Fire and rescue: civil defense, or the fire service.
  fire,
  traffic,

  /// Highway or road security patrols.
  roadSecurity,
}

/// How a number was checked.
enum Verification {
  /// Stated by an official national source (a ministry, the police, civil
  /// defense, the ambulance service, the official news agency).
  official,

  /// Only a foreign government's official advice (an embassy) states it:
  /// shown, but marked to be confirmed locally.
  secondary,
}

/// Text written in both languages, inside the dataset.
final class LocalizedText extends Equatable {
  const LocalizedText({required this.en, required this.ar});

  final String en;
  final String ar;

  String of(String languageCode) => languageCode == 'ar' ? ar : en;

  @override
  List<Object?> get props => <Object?>[en, ar];
}

/// Where a number was checked.
final class EmergencySource extends Equatable {
  const EmergencySource({
    required this.id,
    required this.publisher,
    required this.url,
  });

  final String id;
  final LocalizedText publisher;
  final Uri url;

  @override
  List<Object?> get props => <Object?>[id, publisher, url];
}

/// One number and every service it answers.
final class EmergencyService extends Equatable {
  const EmergencyService({
    required this.types,
    required this.number,
    required this.verification,
    required this.sourceIds,
    this.note,
  });

  final List<EmergencyServiceType> types;

  /// Digits only, as dialled.
  final String number;
  final Verification verification;
  final List<String> sourceIds;

  /// Where it applies, when not everywhere.
  final LocalizedText? note;

  @override
  List<Object?> get props => <Object?>[
    types,
    number,
    verification,
    sourceIds,
    note,
  ];
}

/// A country's emergency numbers, their sources and when they were checked.
final class EmergencyCountry extends Equatable {
  const EmergencyCountry({
    required this.code,
    required this.checkedOn,
    required this.services,
    required this.sources,
    this.note,
  });

  /// ISO 3166-1 alpha-2, matching `Countries`.
  final String code;
  final DateTime checkedOn;

  /// The general number first, then the rest, as the dataset orders them.
  final List<EmergencyService> services;
  final List<EmergencySource> sources;

  /// Something about the whole country (where the general number applies).
  final LocalizedText? note;

  /// The number for [type], if the country has one.
  EmergencyService? serviceFor(EmergencyServiceType type) {
    for (final EmergencyService s in services) {
      if (s.types.contains(type)) return s;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[
    code,
    checkedOn,
    services,
    sources,
    note,
  ];
}
