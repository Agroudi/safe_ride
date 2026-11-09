import 'dart:async';

import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';

/// [EmergencyPositionReader] over the one recording: `JourneyTracker` stays
/// the only source of GPS. It never asks for permission (only `access()`,
/// which reads it), takes a new reading only in [locateNow], and sends
/// nothing anywhere: what it returns is for the user's own screen.
class TrackerPositionReader implements EmergencyPositionReader {
  TrackerPositionReader(this._tracker, this._journeys);

  final JourneyTracker _tracker;
  final JourneyRepository _journeys;

  /// The journey list comes from the shared live query, offline too; this
  /// only guards against waiting on it when the phone has no copy yet.
  static const Duration journeyWait = Duration(seconds: 3);

  @override
  Future<EmergencyPosition> lastKnown() async =>
      _position(await _access(), _tracker.lastFix);

  @override
  Future<EmergencyPosition> locateNow() async {
    final PositionAccess access = await _access();
    final bool readable =
        access == PositionAccess.allowed ||
        access == PositionAccess.approximate;
    return _position(access, readable ? await _tracker.locate() : null);
  }

  Future<EmergencyPosition> _position(
    PositionAccess access,
    LocationFix? fix,
  ) async {
    final PositionReading? reading = fix == null
        ? null
        : PositionReading(
            latitude: fix.latitude,
            longitude: fix.longitude,
            at: fix.at.toUtc(),
            accuracy: fix.accuracy > 0 ? fix.accuracy : null,
          );
    return EmergencyPosition(
      access: access,
      reading: reading != null && reading.valid ? reading : null,
      destination: await _destination(),
    );
  }

  Future<PositionAccess> _access() async {
    try {
      return switch (await _tracker.access()) {
        LocationAccess.granted => PositionAccess.allowed,
        LocationAccess.approximate => PositionAccess.approximate,
        LocationAccess.serviceOff => PositionAccess.servicesOff,
        LocationAccess.denied ||
        LocationAccess.deniedForever => PositionAccess.notAllowed,
      };
    } on Object {
      return PositionAccess.notAllowed;
    }
  }

  /// The journey in progress — the one being recorded, else any active one.
  Future<String?> _destination() async {
    try {
      final List<JourneyModel> all = await _journeys.journeys().timeout(
        journeyWait,
      );
      final String? recording = _tracker.journeyId;
      JourneyModel? active;
      for (final JourneyModel j in all) {
        if (j.status != JourneyStatus.active) continue;
        if (j.id == recording) return j.destination;
        active ??= j;
      }
      return active?.destination;
    } on Object {
      return null;
    }
  }
}
