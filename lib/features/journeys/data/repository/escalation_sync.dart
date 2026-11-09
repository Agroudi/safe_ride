import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';

/// Reports escalation-ready safety checks to the backend, one request each.
/// With no backend ([live] false, as on Firebase's Spark plan) it sends
/// nothing: the checks stay on the phone, and the app says nobody was alerted.
///
/// - **When:** as a check becomes escalation-ready, on sign-in, at app start
///   and on every return to the foreground ([flush]).
/// - **Offline:** the request waits in Firestore's own queue, on disk; the
///   check keeps when it was queued and when the server confirmed it, and
///   its event time never changes. Nothing here claims an alert went out:
///   that is only ever read back from the backend's record.
/// - **Duplicates:** at most one write per check per run of the app. A
///   second one after a restart is refused by the rules (a request is never
///   rewritten) and the backend keys the escalation on the check's id, so
///   one check can never become two escalations.
class EscalationSync {
  EscalationSync({
    required SafetyCheckRepository checks,
    required IncidentRepository incidents,
    required EscalationRepository repository,
    required SessionReader session,
    required Stream<SafetyCheck?> updates,
    required this.live,
    DateTime Function()? clock,
  }) : _checks = checks,
       _incidents = incidents,
       _repository = repository,
       _session = session,
       _clock = clock ?? DateTime.now {
    _subscriptions = <StreamSubscription<void>>[
      updates.listen((SafetyCheck? c) {
        if (c?.status == SafetyCheckStatus.escalationReady) unawaited(flush());
      }),
      session.changes.listen((_) => unawaited(flush())),
    ];
  }

  final SafetyCheckRepository _checks;
  final IncidentRepository _incidents;
  final EscalationRepository _repository;
  final SessionReader _session;
  final DateTime Function() _clock;
  late final List<StreamSubscription<void>> _subscriptions;

  /// Whether a backend exists to receive requests.
  final bool live;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Set<String> _sent = <String>{};
  Future<void> _queue = Future<void>.value();

  /// Fires when a request was queued or confirmed.
  Stream<void> get changes => _changes.stream;

  /// Sends what has not reached the server.
  Future<void> flush() =>
      _queue = _queue.then((_) => _flush()).catchError((Object e) {
        debugPrint('Escalation sync: stopped (${e.runtimeType})');
      });

  Future<void> _flush() async {
    if (!live) return;
    final String? uid = (await _session.signedInUser())?.id;
    if (uid == null) return;
    for (final SafetyCheck c in await _checks.forUser(uid)) {
      if (c.status != SafetyCheckStatus.escalationReady ||
          // The user said they are okay before it was sent: nothing to send.
          c.resolvedAt != null ||
          c.escalationSyncedAt != null ||
          _sent.contains(c.id)) {
        continue;
      }
      final PotentialIncident? incident = await _incidentOf(c);
      if (incident == null) continue;
      _sent.add(c.id);
      final SafetyCheck queued = c.copyWith(
        escalationQueuedAt: c.escalationQueuedAt ?? _now(),
      );
      await _save(queued);
      unawaited(_send(queued, incident));
    }
  }

  Future<void> _send(SafetyCheck c, PotentialIncident incident) async {
    try {
      await _repository.submit(c, incident);
      await _confirmed(c.id, c.uid);
    } on Object catch (e) {
      // Refused: normally an earlier run's request already there.
      try {
        if (await _repository.received(c.uid, c.id)) {
          return await _confirmed(c.id, c.uid);
        }
      } on Object {
        // Unreachable: the next flush asks again.
      }
      debugPrint('Escalation sync: not sent (${e.runtimeType})');
      _sent.remove(c.id);
    }
  }

  Future<void> _confirmed(String id, String uid) async {
    for (final SafetyCheck c in await _checks.forUser(uid)) {
      if (c.id == id) await _save(c.copyWith(escalationSyncedAt: _now()));
    }
  }

  Future<void> _save(SafetyCheck c) async {
    await _checks.put(c);
    _changes.add(null);
  }

  Future<PotentialIncident?> _incidentOf(SafetyCheck c) async {
    for (final PotentialIncident i in await _incidents.forJourney(
      c.uid,
      c.journeyId,
    )) {
      if (i.id == c.incidentId) return i;
    }
    return null;
  }

  DateTime _now() => _clock().toUtc();

  /// Done when every queued flush has run (tests).
  Future<void> get idle => _queue;

  /// Stops listening (tests; the app keeps one for its lifetime).
  Future<void> dispose() async {
    for (final StreamSubscription<void> s in _subscriptions) {
      await s.cancel();
    }
    await _changes.close();
  }
}
