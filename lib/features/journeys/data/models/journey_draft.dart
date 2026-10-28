import 'package:flutter/foundation.dart';

/// What the plan screen collected — two places and a departure — on its way
/// to review. Not stored: a journey exists only once it is confirmed.
/// Travels as a JSON-safe map in go_router's `extra`, so state restoration
/// never warns.
@immutable
class JourneyDraft {
  const JourneyDraft({
    required this.origin,
    required this.destination,
    required this.departsAt,
  });

  final String origin;
  final String destination;

  /// UTC.
  final DateTime departsAt;

  Map<String, String> toExtra() => <String, String>{
    'origin': origin,
    'destination': destination,
    'departsAt': departsAt.toUtc().toIso8601String(),
  };

  /// Null unless [extra] is a draft with both places and a departure.
  static JourneyDraft? from(Object? extra) {
    if (extra is! Map) return null;
    final Object? origin = extra['origin'];
    final Object? destination = extra['destination'];
    final Object? departs = extra['departsAt'];
    if (origin is! String || destination is! String || departs is! String) {
      return null;
    }
    final DateTime? departsAt = DateTime.tryParse(departs);
    if (origin.trim().isEmpty || destination.trim().isEmpty) return null;
    if (departsAt == null) return null;
    return JourneyDraft(
      origin: origin,
      destination: destination,
      departsAt: departsAt.toUtc(),
    );
  }
}
