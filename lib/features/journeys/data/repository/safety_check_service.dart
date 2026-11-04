import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';

/// Schedules [callback] after [after]; `Timer.new` in the app, a fake in
/// tests (no test waits 15 real seconds).
typedef SafetyTimer = Timer Function(Duration after, void Function() callback);

/// Which potential incidents ask "Are you okay?".
abstract final class SafetyCheckEligibility {
  /// An event older than this when the app sees it (the app was closed
  /// meanwhile) asks nothing: a question minutes late helps no one. It is
  /// left for the journey screen's quieter note.
  static const Duration maxEventAge = Duration(minutes: 2);

  /// Eligible when all hold:
  /// - still open (`detected`) — never dismissed, resolved, superseded, or
  ///   already asked about;
  /// - a movement event (sudden deceleration, prolonged stop) — a tracking
  ///   interruption never asks: missing data is not evidence;
  /// - medium or high confidence — a low one is kept, not asked;
  /// - noticed within [maxEventAge].
  ///
  /// The service adds: no check yet for this incident (one per incident,
  /// ever), none pending for the account, and the journey still in
  /// progress.
  static bool eligible(PotentialIncident i, DateTime now) =>
      i.status == IncidentStatus.detected &&
      i.type != IncidentType.trackingInterrupted &&
      i.confidence != IncidentConfidence.low &&
      !now.isBefore(i.detectedAt) &&
      now.difference(i.detectedAt) <= maxEventAge;
}

/// What became of a tap on "I'm safe".
enum ConfirmOutcome {
  /// Recorded; nothing more happens for this incident.
  confirmed,

  /// The deadline had passed first: the check timed out, and stays so.
  tooLate,

  /// The check was no longer pending (answered, cancelled): nothing done.
  notPending,
}

/// Asks "Are you okay?" about eligible potential incidents and keeps the
/// 15-second countdown — the app-wide service the prompt shows.
///
/// - **The countdown is a deadline**, stored with the check. One timer is
///   armed for it, but the time left is always `deadline − now`: a missed
///   tick, a rebuilt screen or a suspended app never stretches it. On
///   [recover] (app start, return to the foreground, sign-in) an overdue
///   pending check times out at once.
/// - **Exactly once:** every change runs in one queue and re-reads the
///   stored check; a move the state machine forbids is never written. "I'm
///   safe" at or after the deadline is too late; a second tap does nothing.
/// - **Timed out** marks the incident `escalationReady` — no answer, not an
///   accident — and `EscalationSync` takes it from there.
/// - **Cancelled** when the journey ends or the account signs out.
/// - **Off screen** the question is a notification ([SafetyNotifications]):
///   shown only while the app is not in the foreground, so it never doubles
///   the prompt. An "I'm safe" tapped on it counts from the moment of the
///   tap, even if the app reads it later.
class SafetyCheckService {
  SafetyCheckService({
    required IncidentRepository incidents,
    required SafetyCheckRepository checks,
    required JourneyRepository journeys,
    required SessionReader session,
    required SafetyNotifications notifications,
    required bool Function() inForeground,
    DateTime Function()? clock,
    SafetyTimer? timer,
    this.duration = const Duration(seconds: 15),
  }) : _incidents = incidents,
       _checks = checks,
       _journeys = journeys,
       _session = session,
       _notifications = notifications,
       _inForeground = inForeground,
       _clock = clock ?? DateTime.now,
       _timer = timer ?? Timer.new {
    _subscriptions = <StreamSubscription<void>>[
      incidents.changes.listen((_) => _serial(_evaluate)),
      journeys.changes.listen((_) => _serial(_journeyEnded)),
      session.changes.listen((_) => _serial(_accountChanged)),
      notifications.answered.listen((_) => _serial(_applyAnswers)),
    ];
  }

  final IncidentRepository _incidents;
  final SafetyCheckRepository _checks;
  final JourneyRepository _journeys;
  final SessionReader _session;
  final SafetyNotifications _notifications;
  final bool Function() _inForeground;
  final DateTime Function() _clock;
  final SafetyTimer _timer;
  final Duration duration;

  /// How soon a check whose write failed is looked at again.
  static const Duration writeRetry = Duration(seconds: 5);

  final StreamController<SafetyCheck?> _changes =
      StreamController<SafetyCheck?>.broadcast();
  late final List<StreamSubscription<void>> _subscriptions;
  Future<void> _queue = Future<void>.value();
  Timer? _armed;
  SafetyCheck? _current;

  /// What the notification shows now, so nothing is posted twice.
  String? _noticed;

  /// The check to show: pending, or timed out and not yet acknowledged.
  SafetyCheck? get current => _current;

  Stream<SafetyCheck?> get changes => _changes.stream;

  DateTime now() => _clock().toUtc();

  /// Picks up where the app left off: an overdue check times out, a running
  /// one is shown again, and new eligible incidents are asked about.
  Future<void> recover() => _serial(_recoverNow);

  /// The app left the screen, or came back: the question moves between the
  /// prompt and the notification.
  Future<void> foregroundChanged() => _serial(_notice);

  Future<void> _recoverNow() async {
    try {
      await _notifications.prepare();
    } on Object {
      // No notifications on this phone: the prompt still works.
    }
    await _applyAnswers();
    final String? uid = await _uid();
    if (uid == null) return _show(null);
    for (final SafetyCheck c in await _checks.forUser(uid)) {
      if (c.status == SafetyCheckStatus.timedOut) await _handOver(c);
      if (c.status != SafetyCheckStatus.pending) continue;
      if (await _active(c.journeyId) == false) {
        await _cancel(c, SafetyCheckCancelReason.journeyEnded);
      } else if (!now().isBefore(c.deadline)) {
        await _timeOut(c);
      } else {
        _arm(c);
        _show(c);
      }
    }
    await _evaluate();
    await _notice();
  }

  /// The user's "I'm safe".
  Future<ConfirmOutcome> confirm(String checkId) {
    final Completer<ConfirmOutcome> outcome = Completer<ConfirmOutcome>();
    unawaited(
      _serial(() async {
        try {
          await _confirm(checkId, outcome);
        } finally {
          // Whatever happened, the tap gets an answer.
          if (!outcome.isCompleted) outcome.complete(ConfirmOutcome.notPending);
        }
      }),
    );
    return outcome.future;
  }

  Future<void> _confirm(
    String checkId,
    Completer<ConfirmOutcome> outcome,
  ) async {
    final SafetyCheck? c = await _find(checkId);
    if (c == null || c.status != SafetyCheckStatus.pending) {
      return outcome.complete(ConfirmOutcome.notPending);
    }
    final DateTime at = now();
    if (!at.isBefore(c.deadline)) {
      await _timeOut(c);
      return outcome.complete(ConfirmOutcome.tooLate);
    }
    await _confirmed(c, at);
    outcome.complete(ConfirmOutcome.confirmed);
  }

  Future<void> _confirmed(SafetyCheck c, DateTime at) async {
    _armed?.cancel();
    await _write(
      c,
      SafetyCheckStatus.confirmedSafe,
      (SafetyCheck x) => x.copyWith(confirmedAt: at),
    );
    await _setIncident(
      c,
      (PotentialIncident i) => i.copyWith(
        status: IncidentStatus.dismissed,
        resolution: IncidentResolution.confirmedSafe,
        updatedAt: at,
      ),
    );
    _show(null);
  }

  /// "I'm safe" taps made on the notification. What counts is when the tap
  /// was written down, not when the app got round to reading it.
  Future<void> _applyAnswers() async {
    final Map<String, DateTime> answers = await _notifications.takeAnswers();
    for (final MapEntry<String, DateTime> a in answers.entries) {
      final SafetyCheck? c = await _find(a.key);
      if (c == null || c.status != SafetyCheckStatus.pending) continue;
      if (a.value.isBefore(c.deadline)) {
        await _confirmed(c, a.value);
      } else {
        await _timeOut(c);
      }
    }
  }

  /// The account is being deleted: stops asking, and writes nothing more.
  Future<void> forget() => _serial(() async {
    _armed?.cancel();
    _show(null);
  });

  /// The user closed the "no answer" note. Changes nothing stored.
  void acknowledge() {
    final SafetyCheck? c = _current;
    if (c != null && c.status != SafetyCheckStatus.pending) _show(null);
  }

  /// Asks about the newest eligible incident, unless a check is pending.
  Future<void> _evaluate() async {
    final String? uid = await _uid();
    if (uid == null || _current?.status == SafetyCheckStatus.pending) return;
    final List<SafetyCheck> checks = await _checks.forUser(uid);
    if (checks.any((SafetyCheck c) => c.status == SafetyCheckStatus.pending)) {
      return;
    }
    final Set<String> asked = <String>{
      for (final SafetyCheck c in checks) c.incidentId,
    };
    final DateTime at = now();
    final List<PotentialIncident> candidates =
        <PotentialIncident>[
          for (final PotentialIncident i in await _incidents.forUser(uid))
            if (!asked.contains(i.id) && SafetyCheckEligibility.eligible(i, at))
              i,
        ]..sort(
          (PotentialIncident a, PotentialIncident b) =>
              b.detectedAt.compareTo(a.detectedAt),
        );
    for (final PotentialIncident i in candidates) {
      if (await _active(i.journeyId) != true) continue;
      final SafetyCheck check = SafetyCheck(
        id: '${i.id}-check',
        incidentId: i.id,
        journeyId: i.journeyId,
        uid: uid,
        status: SafetyCheckStatus.pending,
        startedAt: at,
        deadline: at.add(duration),
      );
      await _checks.put(check);
      await _incidents.put(
        i.copyWith(status: IncidentStatus.awaitingConfirmation, updatedAt: at),
      );
      _arm(check);
      _show(check);
      return;
    }
  }

  void _arm(SafetyCheck c) {
    _armed?.cancel();
    final Duration left = c.deadline.difference(now());
    _armed = _timer(
      left.isNegative ? Duration.zero : left,
      () => _serial(() => _expire(c.id)),
    );
  }

  Future<void> _expire(String checkId) async {
    await _applyAnswers(); // A tap on the notification may be waiting.
    final SafetyCheck? c = await _find(checkId);
    if (c == null || c.status != SafetyCheckStatus.pending) return;
    if (now().isBefore(c.deadline)) return _arm(c); // Fired early.
    await _timeOut(c);
  }

  Future<void> _timeOut(SafetyCheck c) async {
    _armed?.cancel();
    final SafetyCheck timedOut = await _write(
      c,
      SafetyCheckStatus.timedOut,
      (SafetyCheck x) =>
          x.copyWith(timedOutAt: c.deadline, timeoutProcessedAt: now()),
    );
    await _handOver(timedOut);
  }

  /// Timed out → escalation-ready: `EscalationSync` picks it up.
  Future<void> _handOver(SafetyCheck c) async {
    final DateTime at = now();
    await _setIncident(
      c,
      (PotentialIncident i) =>
          i.copyWith(status: IncidentStatus.escalationReady, updatedAt: at),
    );
    _show(
      await _write(
        c,
        SafetyCheckStatus.escalationReady,
        (SafetyCheck x) => x.copyWith(escalationReadyAt: at),
      ),
    );
  }

  Future<void> _cancel(SafetyCheck c, SafetyCheckCancelReason reason) async {
    _armed?.cancel();
    final DateTime at = now();
    await _write(
      c,
      SafetyCheckStatus.cancelled,
      (SafetyCheck x) => x.copyWith(cancelledAt: at, cancelReason: reason),
    );
    await _setIncident(
      c,
      (PotentialIncident i) => i.copyWith(
        status: IncidentStatus.resolved,
        resolution: IncidentResolution.checkCancelled,
        updatedAt: at,
      ),
    );
    if (_current?.id == c.id) _show(null);
  }

  /// The pending check's journey ended (completed or cancelled).
  Future<void> _journeyEnded() async {
    final SafetyCheck? c = _current;
    if (c == null || c.status != SafetyCheckStatus.pending) return;
    if (await _active(c.journeyId) == false) {
      await _cancel(c, SafetyCheckCancelReason.journeyEnded);
    }
  }

  /// Signed out, or another account: its pending check is cancelled.
  Future<void> _accountChanged() async {
    final SafetyCheck? c = _current;
    if (c == null || await _uid() == c.uid) return;
    if (c.status == SafetyCheckStatus.pending) {
      await _cancel(c, SafetyCheckCancelReason.signedOut);
    }
    _show(null);
    await _recoverNow(); // Another account may have its own to resume.
  }

  /// Writes [to] only if the state machine allows it from the stored state.
  Future<SafetyCheck> _write(
    SafetyCheck c,
    SafetyCheckStatus to,
    SafetyCheck Function(SafetyCheck) details,
  ) async {
    if (!c.status.canMoveTo(to)) {
      throw StateError('${c.status.name} → ${to.name} is not allowed');
    }
    final SafetyCheck next = details(c).copyWith(status: to);
    await _checks.put(next);
    return next;
  }

  Future<void> _setIncident(
    SafetyCheck c,
    PotentialIncident Function(PotentialIncident) change,
  ) async {
    for (final PotentialIncident i in await _incidents.forJourney(
      c.uid,
      c.journeyId,
    )) {
      if (i.id == c.incidentId) return _incidents.put(change(i));
    }
  }

  Future<SafetyCheck?> _find(String id) async {
    final String? uid = _current?.uid ?? await _uid();
    if (uid == null) return null;
    for (final SafetyCheck c in await _checks.forUser(uid)) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Whether the journey is in progress; null when it cannot be read.
  Future<bool?> _active(String journeyId) async {
    try {
      return (await _journeys.journey(journeyId))?.status ==
          JourneyStatus.active;
    } on JourneyFailure {
      return null;
    }
  }

  Future<String?> _uid() async => (await _session.signedInUser())?.id;

  void _show(SafetyCheck? c) {
    _current = c;
    _changes.add(c);
    unawaited(_notice());
  }

  /// Keeps the notification in step with [current]: none while the app is
  /// on screen, and never one that a failure here could turn into a broken
  /// check — the countdown does not depend on it.
  Future<void> _notice() async {
    final SafetyCheck? c = _current;
    final String? want = c == null || _inForeground()
        ? null
        : '${c.id}/${c.status.name}';
    if (want == _noticed) return;
    _noticed = want;
    try {
      if (want == null) {
        await _notifications.clear();
      } else if (c!.status == SafetyCheckStatus.pending) {
        await _notifications.asking(c);
      } else {
        await _notifications.noAnswer();
      }
    } on Object catch (e) {
      debugPrint('Safety notice: not updated (${e.runtimeType})');
    }
  }

  /// Runs [step] after every earlier one; its error never escapes.
  Future<void> _serial(Future<void> Function() step) =>
      _queue = _queue.then((_) => step()).catchError((Object _) {
        // A failed write (a full disk) must not leave a check with no timer.
        final SafetyCheck? c = _current;
        if (c?.status != SafetyCheckStatus.pending) return;
        _armed?.cancel();
        _armed = _timer(writeRetry, () => _serial(() => _expire(c!.id)));
      });

  /// Done when every queued step has run (tests).
  Future<void> get idle => _queue;

  /// Stops listening (tests; the app keeps one for its lifetime).
  Future<void> dispose() async {
    _armed?.cancel();
    for (final StreamSubscription<void> s in _subscriptions) {
      await s.cancel();
    }
    await _changes.close();
  }
}
