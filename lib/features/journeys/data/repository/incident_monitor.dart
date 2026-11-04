import 'dart:async';

import 'package:safe_ride/features/journeys/data/models/incident_detection_config.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_detection_engine.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/tracking_observer.dart';

/// Turns the tracker's recording into stored potential-incident events:
/// one [IncidentDetectionEngine] for the journey being recorded (a new
/// journey always starts from a fresh engine, so nothing carries over), and
/// the event lifecycle in [IncidentRepository].
///
/// **Lifecycle.** detected → resolved (the condition ended, or the journey
/// did) · dismissed (the user said they are fine) · superseded (a newer
/// event about the same thing replaced it). At most one open movement event
/// (sudden deceleration, prolonged stop) and one open interruption per
/// journey; the same condition is never stored twice. It sends nothing,
/// calls no one, and alerts no one.
class IncidentMonitor implements TrackingObserver {
  IncidentMonitor(
    this._repository, {
    this.config = const IncidentDetectionConfig(),
  });

  final IncidentRepository _repository;
  final IncidentDetectionConfig config;

  IncidentDetectionEngine? _engine;
  String? _uid;

  /// The events this engine noticed. One left open by an earlier engine (the
  /// app was closed) can never be cleared by this one, so it must not count
  /// as the same condition and swallow a new event.
  final Set<String> _noticed = <String>{};

  /// Keeps ids unique when two events share an instant.
  int _sequence = 0;
  Future<void> _queue = Future<void>.value();

  /// Done when every event so far is stored (tests; the app never waits).
  Future<void> get idle => _queue;

  @override
  void started(
    String uid,
    String journeyId,
    DateTime at, {
    DateTime? lastFixBefore,
  }) {
    if (_engine?.journeyId != journeyId || _uid != uid) {
      _engine = IncidentDetectionEngine(journeyId: journeyId, config: config);
      _noticed.clear();
    }
    _uid = uid;
    _apply(_engine!.started(at, lastFixBefore: lastFixBefore));
  }

  @override
  void fixed(String journeyId, LocationFix fix, DateTime at) =>
      _on(journeyId, (IncidentDetectionEngine e) => e.fix(fix, at));

  @override
  void ticked(String journeyId, DateTime at) =>
      _on(journeyId, (IncidentDetectionEngine e) => e.tick(at));

  @override
  void interrupted(String journeyId, InterruptionCause cause, DateTime at) =>
      _on(journeyId, (IncidentDetectionEngine e) => e.interrupted(cause, at));

  @override
  void paused(String journeyId) {
    if (_engine?.journeyId == journeyId) _engine = null;
  }

  @override
  void ended(String uid, String journeyId, DateTime at) {
    if (_engine?.journeyId == journeyId) _engine = null;
    _serial(() async {
      for (final PotentialIncident i in await _open(uid, journeyId)) {
        await _repository.put(
          i.copyWith(
            status: IncidentStatus.resolved,
            resolution: IncidentResolution.journeyEnded,
            updatedAt: at.toUtc(),
          ),
        );
      }
    });
  }

  void _on(
    String journeyId,
    List<DetectorOutput> Function(IncidentDetectionEngine) step,
  ) {
    final IncidentDetectionEngine? engine = _engine;
    if (engine == null || engine.journeyId != journeyId) return;
    _apply(step(engine));
  }

  void _apply(List<DetectorOutput> outputs) {
    final IncidentDetectionEngine? engine = _engine;
    final String? uid = _uid;
    if (engine == null || uid == null) return;
    for (final DetectorOutput o in outputs) {
      _serial(
        () => switch (o) {
          IncidentDetected(:final IncidentSignal signal) => _record(
            uid,
            engine.journeyId,
            signal,
          ),
          IncidentCleared(:final type, :final resolution, :final at) => _clear(
            uid,
            engine.journeyId,
            type,
            resolution,
            at,
          ),
        },
      );
    }
  }

  Future<void> _record(String uid, String journeyId, IncidentSignal s) async {
    final List<PotentialIncident> open = <PotentialIncident>[
      for (final PotentialIncident i in await _open(uid, journeyId))
        if (_family(i.type) == _family(s.type)) i,
    ];
    // The same condition, still open: a duplicate.
    if (s.type != IncidentType.trackingInterrupted &&
        open.any(
          (PotentialIncident i) => i.type == s.type && _noticed.contains(i.id),
        )) {
      return;
    }
    final DateTime at = s.at.toUtc();
    final String id =
        '$journeyId-${s.type.name}-${at.millisecondsSinceEpoch}-${_sequence++}';
    _noticed.add(id);
    for (final PotentialIncident old in open) {
      await _repository.put(
        old.copyWith(
          status: IncidentStatus.superseded,
          resolution: IncidentResolution.replaced,
          supersededBy: id,
          updatedAt: at,
        ),
      );
    }
    await _repository.put(
      PotentialIncident(
        id: id,
        journeyId: journeyId,
        uid: uid,
        type: s.type,
        status: IncidentStatus.detected,
        confidence: s.confidence,
        detectedAt: at,
        updatedAt: at,
        reason: s.reason,
        speedBeforeKmh: _kmh(s.speedBefore),
        speedAfterKmh: _kmh(s.speedAfter),
        deceleration: s.deceleration,
        durationSeconds: s.duration?.inSeconds,
        lat: _rounded(s.lat),
        lng: _rounded(s.lng),
        accuracyMeters: s.accuracy,
        fixAgeSeconds: s.fixAge == null
            ? null
            : s.fixAge!.inMilliseconds / 1000,
        interruption: s.interruption,
      ),
    );
  }

  Future<void> _clear(
    String uid,
    String journeyId,
    IncidentType type,
    IncidentResolution resolution,
    DateTime at,
  ) async {
    for (final PotentialIncident i in await _open(uid, journeyId)) {
      if (i.type != type) continue;
      await _repository.put(
        i.copyWith(
          status: IncidentStatus.resolved,
          resolution: resolution,
          updatedAt: at.toUtc(),
        ),
      );
    }
  }

  Future<List<PotentialIncident>> _open(String uid, String journeyId) async =>
      <PotentialIncident>[
        for (final PotentialIncident i in await _repository.forJourney(
          uid,
          journeyId,
        ))
          if (i.status == IncidentStatus.detected) i,
      ];

  void _serial(Future<void> Function() step) =>
      _queue = _queue.then((_) => step()).catchError((Object _) {});

  /// Movement events replace each other; interruptions replace each other.
  static bool _family(IncidentType t) => t == IncidentType.trackingInterrupted;

  static double? _kmh(double? metresPerSecond) =>
      metresPerSecond == null ? null : metresPerSecond * 3.6;

  /// Four decimals: about 11 m — enough to find someone, no closer.
  static double? _rounded(double? degrees) =>
      degrees == null ? null : (degrees * 10000).roundToDouble() / 10000;
}
