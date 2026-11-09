import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';

import '../tracking_fakes.dart';

class _Session implements SessionReader {
  String? uid = 'sara';
  final StreamController<void> changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => changed.stream;

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

/// The escalation lifecycle, transition by transition: what a timeout
/// prepares, how it is shown, how it closes, and that nothing doubles or
/// reopens. Time moves only by hand.
void main() {
  late FakeFirebaseFirestore db;
  late _Session session;
  late FirestoreJourneyRepository journeys;
  late MemoryIncidentRepository incidents;
  late MemorySafetyCheckRepository checks;
  late FakeSafetyNotifications notices;
  late DateTime now;
  late FakeTimers timers;
  late bool foreground;
  final List<SafetyCheckService> services = <SafetyCheckService>[];

  setUp(() {
    db = FakeFirebaseFirestore();
    session = _Session();
    journeys = FirestoreJourneyRepository(db, session);
    incidents = MemoryIncidentRepository();
    checks = MemorySafetyCheckRepository();
    notices = FakeSafetyNotifications();
    now = DateTime.utc(2026, 11, 8, 9);
    timers = FakeTimers(() => now);
    foreground = true;
  });

  tearDown(() async {
    for (final SafetyCheckService s in services) {
      await s.dispose();
    }
    services.clear();
  });

  SafetyCheckService service() {
    final SafetyCheckService s = SafetyCheckService(
      incidents: incidents,
      checks: checks,
      journeys: journeys,
      session: session,
      notifications: notices,
      inForeground: () => foreground,
      clock: () => now,
      timer: timers.call,
    );
    services.add(s);
    return s;
  }

  Future<JourneyModel> active() async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await journeys.start(
      j.id,
      checklistVersion: 1,
      confirmed: JourneyChecklist.itemsOf(1).toSet(),
    );
    return j;
  }

  PotentialIncident incident(
    JourneyModel j, {
    String id = 'e1',
    IncidentConfidence confidence = IncidentConfidence.medium,
  }) => PotentialIncident(
    id: id,
    journeyId: j.id,
    uid: 'sara',
    type: IncidentType.prolongedStop,
    status: IncidentStatus.detected,
    confidence: confidence,
    detectedAt: now.subtract(const Duration(seconds: 3)),
    updatedAt: now.subtract(const Duration(seconds: 3)),
    reason: 'still within 30 m for 301 s after moving',
    lat: 24.7,
    lng: 46.67,
  );

  Future<void> settle(SafetyCheckService s) async {
    await pumpEventQueue();
    await s.idle;
  }

  Future<void> detect(SafetyCheckService s, PotentialIncident i) async {
    await incidents.put(i);
    await settle(s);
  }

  Future<void> advance(SafetyCheckService s, Duration d) async {
    now = now.add(d);
    timers.fireDue();
    await settle(s);
  }

  PotentialIncident stored(String id) =>
      incidents.all.firstWhere((PotentialIncident i) => i.id == id);

  SafetyCheck only() => checks.all.single;

  group('the stages, derived from the record', () {
    SafetyCheck check(SafetyCheckStatus status) => SafetyCheck(
      id: 'e1-check',
      incidentId: 'e1',
      journeyId: 'j1',
      uid: 'sara',
      status: status,
      startedAt: DateTime.utc(2026),
      deadline: DateTime.utc(2026).add(const Duration(seconds: 15)),
    );

    test('every status maps to exactly one stage', () {
      expect(
        check(SafetyCheckStatus.pending).stage,
        SafetyStage.awaitingUserConfirmation,
      );
      expect(
        check(SafetyCheckStatus.confirmedSafe).stage,
        SafetyStage.confirmedSafe,
      );
      expect(check(SafetyCheckStatus.timedOut).stage, SafetyStage.timedOut);
      expect(check(SafetyCheckStatus.cancelled).stage, SafetyStage.cancelled);
      final SafetyCheck ready = check(SafetyCheckStatus.escalationReady);
      final DateTime at = DateTime.utc(2026, 1, 2);
      expect(ready.stage, SafetyStage.escalationPrepared);
      expect(ready.presented(at).stage, SafetyStage.awaitingUserAction);
      expect(
        ready.presented(at).resolved(EscalationResolution.userSafe, at).stage,
        SafetyStage.resolved,
      );
      expect(
        ready.resolved(EscalationResolution.journeyEnded, at).stage,
        SafetyStage.resolved,
        reason: 'a journey can end before anyone saw it',
      );
    });

    test('presenting and resolving happen once, and only where they may', () {
      final DateTime a = DateTime.utc(2026, 1, 2);
      final DateTime b = DateTime.utc(2026, 1, 3);
      final SafetyCheck seen = check(
        SafetyCheckStatus.escalationReady,
      ).presented(a);
      expect(seen.presented(b).presentedAt, a);
      final SafetyCheck closed = seen.resolved(
        EscalationResolution.userSafe,
        a,
      );
      expect(
        identical(
          closed.resolved(EscalationResolution.journeyEnded, b),
          closed,
        ),
        isTrue,
      );
      expect(closed.presented(b), same(closed));
      for (final SafetyCheckStatus s in <SafetyCheckStatus>[
        SafetyCheckStatus.pending,
        SafetyCheckStatus.confirmedSafe,
        SafetyCheckStatus.timedOut,
        SafetyCheckStatus.cancelled,
      ]) {
        final SafetyCheck c = check(s);
        expect(c.presented(a), same(c), reason: s.name);
        expect(c.resolved(EscalationResolution.userSafe, a), same(c));
      }
    });

    test('final stages are final', () {
      expect(
        SafetyStage.values.where((SafetyStage s) => s.isFinal).toSet(),
        <SafetyStage>{
          SafetyStage.confirmedSafe,
          SafetyStage.resolved,
          SafetyStage.cancelled,
        },
      );
    });
  });

  group('detection to confirmation', () {
    test(
      'an eligible incident asks, and the record keeps what was noticed',
      () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        final PotentialIncident i = incident(j);
        await detect(s, i);
        final SafetyCheck c = only();
        expect(c.stage, SafetyStage.awaitingUserConfirmation);
        expect(c.incidentType, IncidentType.prolongedStop);
        expect(c.incidentConfidence, IncidentConfidence.medium);
        expect(c.incidentDetectedAt, i.detectedAt);
        expect(c.startedAt, now, reason: 'the countdown starts when asked');
      },
    );

    test('"I\'m safe" ends it: nothing to escalate, nothing open', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      expect(await s.confirm(only().id), ConfirmOutcome.confirmed);
      await settle(s);
      expect(only().stage, SafetyStage.confirmedSafe);
      expect(await s.latestOpen(), isNull);
      expect(await s.resolveSafe(only().id), ResolveOutcome.notOpen);
      await advance(s, const Duration(minutes: 5));
      expect(only().stage, SafetyStage.confirmedSafe);
    });
  });

  group('a timeout', () {
    test('prepares one escalation; shown at once in the foreground', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      final DateTime deadline = only().deadline;
      await advance(s, const Duration(seconds: 15));

      final SafetyCheck c = only();
      expect(c.stage, SafetyStage.awaitingUserAction);
      expect(c.timedOutAt, deadline);
      expect(c.incidentDetectedAt, isNotNull, reason: 'original time kept');
      expect(stored('e1').status, IncidentStatus.escalationReady);
      expect(stored('e1').reason, contains('301 s'), reason: 'evidence kept');
      expect(s.current?.id, c.id);
      final OpenEscalation? open = await s.latestOpen();
      expect(open?.checkId, c.id);
      expect(open?.timedOutAt, deadline);
    });

    test(
      'in the background: prepared, a notice, and shown once back',
      () async {
        foreground = false;
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        await advance(s, const Duration(seconds: 15));
        expect(only().stage, SafetyStage.escalationPrepared);
        expect(notices.log, <String>[only().id, 'noAnswer']);

        foreground = true;
        s.acknowledge();
        await s.recover();
        await settle(s);
        expect(only().stage, SafetyStage.awaitingUserAction);
        expect(s.current?.id, only().id);
        final DateTime seen = only().presentedAt!;
        s.acknowledge();
        await s.recover();
        await settle(s);
        expect(only().presentedAt, seen, reason: 'shown once');
        expect(s.current, isNull);
      },
    );

    test(
      'back from the background through its notice: marked seen then',
      () async {
        foreground = false;
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        await advance(s, const Duration(seconds: 15));
        expect(s.current?.stage, SafetyStage.escalationPrepared);

        // The notice is tapped: the app comes back with it still on hand.
        foreground = true;
        await s.recover();
        await settle(s);
        expect(only().stage, SafetyStage.awaitingUserAction);
        expect(s.current?.stage, SafetyStage.awaitingUserAction);
      },
    );

    test('processed once, however many times it is noticed', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      await advance(s, const Duration(seconds: 15));
      final int writes = checks.writes;
      // The timer again, a recovery, a late tap on the notification.
      timers.fireDue();
      await s.recover();
      notices.tapSafe(only().id, now);
      await settle(s);
      await s.recover();
      await settle(s);
      expect(checks.all, hasLength(1));
      expect(checks.writes, writes);
      expect(only().stage, SafetyStage.awaitingUserAction);
    });

    test('a late "I\'m okay" closes it, once', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      await advance(s, const Duration(seconds: 15));
      await advance(s, const Duration(minutes: 2));

      expect(await s.resolveSafe(only().id), ResolveOutcome.resolved);
      await settle(s);
      expect(only().stage, SafetyStage.resolved);
      expect(only().resolution, EscalationResolution.userSafe);
      expect(only().resolvedAt, now);
      expect(only().timedOutAt, isNotNull, reason: 'history kept');
      expect(stored('e1').status, IncidentStatus.dismissed);
      expect(stored('e1').resolution, IncidentResolution.confirmedSafe);
      expect(await s.latestOpen(), isNull);
      expect(s.current, isNull);

      final int writes = checks.writes;
      expect(await s.resolveSafe(only().id), ResolveOutcome.notOpen);
      expect(checks.writes, writes);
    });

    test(
      'the journey ending closes it; a pending check is cancelled',
      () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        await advance(s, const Duration(seconds: 15));
        await journeys.complete(j.id);
        await settle(s);
        expect(only().stage, SafetyStage.resolved);
        expect(only().resolution, EscalationResolution.journeyEnded);

        final JourneyModel next = await active();
        await detect(s, incident(next, id: 'e2'));
        await journeys.cancel(next.id);
        await settle(s);
        final SafetyCheck second = checks.all.last;
        expect(second.stage, SafetyStage.cancelled);
        expect(stored('e2').status, IncidentStatus.resolved);
      },
    );

    test('a new journey after an escalation starts clean', () async {
      final SafetyCheckService s = service();
      final JourneyModel first = await active();
      await detect(s, incident(first));
      await advance(s, const Duration(seconds: 15));
      await journeys.complete(first.id);
      await settle(s);

      final JourneyModel second = await active();
      expect(await s.openFor(second.id), isNull);
      await detect(s, incident(second, id: 'e2'));
      expect(checks.all.last.stage, SafetyStage.awaitingUserConfirmation);
      expect(checks.all.first.stage, SafetyStage.resolved);
    });
  });

  group('after the app was killed', () {
    test('a running countdown keeps its deadline', () async {
      final SafetyCheckService first = service();
      final JourneyModel j = await active();
      await detect(first, incident(j));
      final DateTime deadline = only().deadline;
      await first.dispose();
      services.remove(first);

      now = now.add(const Duration(seconds: 6));
      final SafetyCheckService again = service();
      await again.recover();
      await settle(again);
      expect(only().deadline, deadline, reason: 'never restarted');
      expect(again.current?.status, SafetyCheckStatus.pending);
      await advance(again, const Duration(seconds: 8));
      expect(only().status, SafetyCheckStatus.pending);
      await advance(again, const Duration(seconds: 1));
      expect(only().timedOutAt, deadline);
    });

    test(
      'reopened after the deadline: timed out at the deadline, shown once',
      () async {
        final SafetyCheckService first = service();
        final JourneyModel j = await active();
        await detect(first, incident(j));
        final DateTime deadline = only().deadline;
        await first.dispose();
        services.remove(first);

        now = now.add(const Duration(minutes: 10));
        final SafetyCheckService again = service();
        await again.recover();
        await settle(again);
        expect(only().stage, SafetyStage.awaitingUserAction);
        expect(only().timedOutAt, deadline);
        expect(only().timeoutProcessedAt, now);
      },
    );

    test('reopened after "I\'m safe": nothing comes back', () async {
      final SafetyCheckService first = service();
      final JourneyModel j = await active();
      await detect(first, incident(j));
      await first.confirm(only().id);
      await settle(first);
      await first.dispose();
      services.remove(first);

      now = now.add(const Duration(minutes: 10));
      final SafetyCheckService again = service();
      await again.recover();
      await settle(again);
      expect(again.current, isNull);
      expect(only().stage, SafetyStage.confirmedSafe);
    });

    test('"I\'m safe" tapped on the notice while the app was dead counts by '
        'the moment of the tap', () async {
      foreground = false;
      final SafetyCheckService first = service();
      final JourneyModel j = await active();
      await detect(first, incident(j));
      notices.tapSafe(only().id, now.add(const Duration(seconds: 9)));
      await first.dispose();
      services.remove(first);

      now = now.add(const Duration(minutes: 3));
      final SafetyCheckService again = service();
      await again.recover();
      await settle(again);
      expect(only().stage, SafetyStage.confirmedSafe);
    });
  });

  group('notifications', () {
    test('one per check, cleared once answered', () async {
      foreground = false;
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      await s.foregroundChanged();
      await s.foregroundChanged();
      await settle(s);
      expect(notices.log, <String>[only().id]);
      await s.confirm(only().id);
      await settle(s);
      expect(notices.log.last, 'clear');
    });

    test(
      'refused: nothing assumed shown, and tried again once allowed',
      () async {
        foreground = false;
        notices.now = SafetyNoticeAccess.blocked;
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        expect(notices.log, isEmpty);
        expect(only().status, SafetyCheckStatus.pending, reason: 'still asks');

        notices.now = SafetyNoticeAccess.allowed;
        await s.foregroundChanged();
        await settle(s);
        expect(notices.log, <String>[only().id]);
      },
    );

    test('a broken notifier never breaks the countdown', () async {
      foreground = false;
      notices.broken = true;
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      await advance(s, const Duration(seconds: 15));
      expect(only().status, SafetyCheckStatus.escalationReady);
    });

    test(
      'an old notice reopens nothing: a late tap, a tap after "I\'m okay"',
      () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        final String id = only().id;
        await advance(s, const Duration(seconds: 15));
        notices.tapSafe(id, now.add(const Duration(minutes: 1)));
        await settle(s);
        expect(only().stage, SafetyStage.awaitingUserAction);

        await s.resolveSafe(id);
        await settle(s);
        notices.tapSafe(id, now);
        await s.recover();
        await settle(s);
        expect(only().stage, SafetyStage.resolved);
        expect(s.current, isNull);
      },
    );
  });

  group('accounts', () {
    test('signing out cancels a pending check; the next account sees none of '
        'it', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      session.uid = 'omar';
      session.changed.add(null);
      await settle(s);
      expect(checks.all.single.stage, SafetyStage.cancelled);
      expect(checks.all.single.cancelReason, SafetyCheckCancelReason.signedOut);
      expect(s.current, isNull);
      expect(await s.latestOpen(), isNull);
    });

    test(
      'an open escalation stays with its account across a sign-out',
      () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        await advance(s, const Duration(seconds: 15));
        session.uid = 'omar';
        session.changed.add(null);
        await settle(s);
        expect(s.current, isNull);
        expect(await s.latestOpen(), isNull);

        session.uid = 'sara';
        session.changed.add(null);
        await settle(s);
        expect((await s.latestOpen())?.checkId, only().id);
        expect(only().stage, SafetyStage.awaitingUserAction);
      },
    );
  });

  test('nothing here can reach anyone: no backend, no alerts', () {
    expect(AppFeatures.contactAlerts, isFalse);
  });

  test('a closed escalation is never sent, even with a backend', () async {
    final SafetyCheckService s = service();
    final JourneyModel j = await active();
    await detect(s, incident(j));
    await advance(s, const Duration(seconds: 15));
    await s.resolveSafe(only().id);
    await settle(s);
    final FakeEscalations backend = FakeEscalations();
    final EscalationSync sync = EscalationSync(
      checks: checks,
      incidents: incidents,
      repository: backend,
      session: session,
      updates: s.changes,
      live: true,
      clock: () => now,
    );
    await sync.flush();
    await sync.idle;
    expect(backend.submitted, isEmpty);
    await sync.dispose();
  });
}
