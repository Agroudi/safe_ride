import 'package:flutter/foundation.dart';

/// One official emergency number. Data, not code: change a number only
/// against an official source, and update [EmergencyNumber.checkedOn].
@immutable
class EmergencyNumber {
  const EmergencyNumber({required this.service, required this.number});

  /// The translation key's last part (`safety.emergency.services.<service>`).
  final String service;

  /// Digits only, as dialled.
  final String number;

  /// Saudi Arabia, checked against the sources below.
  ///
  /// - 911 is the Unified Emergency Number run by the Ministry of Interior's
  ///   Unified Security Operations Centers — in Riyadh, Makkah, Madinah and
  ///   the Eastern Province (Ministry of Interior; Saudi Press Agency, 2025
  ///   call figures for those four regions).
  /// - Elsewhere: 999 police, 997 ambulance, 998 civil defence, 993 traffic
  ///   police, 996 roads security (stc's emergency-numbers page; the US
  ///   State Department's OSAC country report lists the same).
  static const List<EmergencyNumber> saudiArabia = <EmergencyNumber>[
    EmergencyNumber(service: 'unified', number: '911'),
    EmergencyNumber(service: 'police', number: '999'),
    EmergencyNumber(service: 'ambulance', number: '997'),
    EmergencyNumber(service: 'civilDefense', number: '998'),
    EmergencyNumber(service: 'traffic', number: '993'),
    EmergencyNumber(service: 'roads', number: '996'),
  ];

  /// When [saudiArabia] was last checked against its sources.
  static final DateTime checkedOn = DateTime.utc(2026, 10, 28);
}
