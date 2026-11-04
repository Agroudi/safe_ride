import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';

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

void main() {
  late FakeFirebaseFirestore db;
  late _Session session;
  late FirestoreJourneyRepository journeys;
  late MemoryIncidentRepository incidents;
  late MemorySafetyCheckRepository checks;
  late DateTime now;
  late FakeTimers timers;
  final List<SafetyCheckService> services = <SafetyCheckService>[];

  setUp(() {
    db = FakeFirebaseFirestore();
    session = _Session();
    journeys = FirestoreJourneyRepository(db, session);
    incidents = MemoryIncidentRepository();
    checks = MemorySafetyCheckRepository();
    now = DateTime.utc(2026, 11, 3, 9);
    timers = FakeTimers(() => now);
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
      notifications: FakeSafetyNotifications(),
      inForeground: () => true,
      clock: () => now,
      timer: timers.call,
    );
    services.add(s);
    return s;
  }

  Future<JourneyModel> active([String to = 'Work']) async {
    final JourneyModel j = await journeys.plan(
      origin: 'Home',
      destination: to,
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
    IncidentType type = IncidentType.suddenDeceleration,
    IncidentConfidence confidence = IncidentConfidence.medium,
    IncidentStatus status = IncidentStatus.detected,
    Duration age = const Duration(seconds: 5),
    String uid = 'sara',
  }) => PotentialIncident(
    id: id,
    journeyId: j.id,
    uid: uid,
    type: type,
    status: status,
    confidence: confidence,
    detectedAt: now.subtract(age),
    updatedAt: now.subtract(age),
    reason: 'test',
  );

  /// Stores [i] the way the monitor does, and lets the service react.
  Future<void> detect(SafetyCheckService s, PotentialIncident i) async {
    await incidents.put(i);
    await pumpEventQueue();
    await s.idle;
  }

  /// Moves the clock and fires the timers due — the only way time passes.
  Future<void> advance(SafetyCheckService s, Duration d) async {
    now = now.add(d);
    timers.fireDue();
    await pumpEventQueue();
    await s.idle;
  }

  PotentialIncident stored(String id) =>
      incidents.all.firstWhere((PotentialIncident i) => i.id == id);

  group('eligibility', () {
    test('a medium movement event on an active journey asks — once', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      // Any later change to the stored events re-evaluates: still one.
      await detect(s, stored('e1'));

      expect(checks.all, hasLength(1));
      final SafetyCheck c = checks.all.single;
      expect(c.status, SafetyCheckStatus.pending);
      expect(c.incidentId, 'e1');
      expect(c.journeyId, j.id);
      expect(c.deadline.difference(c.startedAt), const Duration(seconds: 15));
      expect(s.current, c);
      expect(stored('e1').status, IncidentStatus.awaitingConfirmation);
    });

    for (final (String why, PotentialIncident Function(JourneyModel) make)
        in <(String, PotentialIncident Function(JourneyModel))>[
          (
            'a low-confidence event',
            (JourneyModel j) => incident(j, confidence: IncidentConfidence.low),
          ),
          (
            'a tracking interruption',
            (JourneyModel j) => incident(
              j,
              type: IncidentType.trackingInterrupted,
              confidence: IncidentConfidence.high,
            ),
          ),
          (
            'a dismissed event',
            (JourneyModel j) => incident(j, status: IncidentStatus.dismissed),
          ),
          (
            'a resolved event',
            (JourneyModel j) => incident(j, status: IncidentStatus.resolved),
          ),
          (
            'an event minutes old (the app was closed)',
            (JourneyModel j) => incident(j, age: const Duration(minutes: 3)),
          ),
        ]) {
      test('$why asks nothing', () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, make(j));
        expect(checks.all, isEmpty);
        expect(s.current, isNull);
      });
    }

    test('an event of a journey that ended asks nothing', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await journeys.complete(j.id);
      await detect(s, incident(j));
      expect(checks.all, isEmpty);
    });

    test('one check at a time; the next event waits its turn', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      await detect(s, incident(j, id: 'e2', type: IncidentType.prolongedStop));
      expect(checks.all, hasLength(1));
      await s.confirm(checks.all.single.id);
      await s.idle;
      await pumpEventQueue();
      await s.idle;
      expect(checks.all, hasLength(2));
      expect(checks.all.last.incidentId, 'e2');
    });

    test('another account\'s events never ask this one', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j, uid: 'omar'));
      expect(checks.all, isEmpty);
    });
  });

  group('the countdown', () {
    test(
      'no answer in 15 s: timed out, then escalation-ready — once',
      () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        final DateTime deadline = checks.all.single.deadline;

        await advance(s, const Duration(seconds: 14, milliseconds: 999));
        expect(checks.all.single.status, SafetyCheckStatus.pending);

        final int before = checks.writes;
        await advance(s, const Duration(milliseconds: 1));
        final SafetyCheck c = checks.all.single;
        expect(c.status, SafetyCheckStatus.escalationReady);
        expect(c.timedOutAt, deadline);
        expect(c.escalationReadyAt, isNotNull);
        expect(
          checks.writes - before,
          2,
          reason: 'timed out, then handed over',
        );
        expect(stored('e1').status, IncidentStatus.escalationReady);
        expect(stored('e1').reason, 'test', reason: 'details kept');
        expect(s.current?.status, SafetyCheckStatus.escalationReady);

        // Nothing more happens, however long it waits.
        await advance(s, const Duration(minutes: 5));
        expect(checks.writes - before, 2);
        s.acknowledge();
        expect(s.current, isNull);
      },
    );

    for (final Duration after in <Duration>[
      const Duration(seconds: 14),
      const Duration(seconds: 1),
    ]) {
      test('"I\'m safe" after ${after.inSeconds} s: confirmed, never '
          'escalated', () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        await advance(s, after);

        expect(await s.confirm(checks.all.single.id), ConfirmOutcome.confirmed);
        final SafetyCheck c = checks.all.single;
        expect(c.status, SafetyCheckStatus.confirmedSafe);
        expect(c.confirmedAt, now);
        expect(stored('e1').status, IncidentStatus.dismissed);
        expect(stored('e1').resolution, IncidentResolution.confirmedSafe);
        expect(s.current, isNull);
        expect(timers.pending, 0);

        await advance(s, const Duration(seconds: 30));
        expect(checks.all.single.status, SafetyCheckStatus.confirmedSafe);
      });
    }

    test('"I\'m safe" at the deadline, before the timer: too late', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      now = now.add(const Duration(seconds: 15)); // the timer has not fired
      expect(await s.confirm(checks.all.single.id), ConfirmOutcome.tooLate);
      expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
      final int writes = checks.writes;
      timers.fireDue(); // the late timer finds nothing to do
      await s.idle;
      expect(checks.writes, writes);
    });

    test('two taps record one answer', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      final String id = checks.all.single.id;
      final List<ConfirmOutcome> outcomes = await Future.wait(
        <Future<ConfirmOutcome>>[s.confirm(id), s.confirm(id)],
      );
      expect(outcomes, <ConfirmOutcome>[
        ConfirmOutcome.confirmed,
        ConfirmOutcome.notPending,
      ]);
      expect(
        checks.all.where(
          (SafetyCheck c) => c.status == SafetyCheckStatus.confirmedSafe,
        ),
        hasLength(1),
      );
    });

    test('a suspended app: the deadline still counts on return', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      // Suspended for 40 s: no timer ran.
      now = now.add(const Duration(seconds: 40));
      await s.recover();
      final SafetyCheck c = checks.all.single;
      expect(c.status, SafetyCheckStatus.escalationReady);
      expect(c.timedOutAt, c.deadline);
      expect(c.timeoutProcessedAt, now);
    });

    test('back in the foreground in time: the same countdown', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      final DateTime deadline = checks.all.single.deadline;
      now = now.add(const Duration(seconds: 6));
      await s.recover();
      expect(checks.all, hasLength(1));
      expect(checks.all.single.deadline, deadline, reason: 'not restarted');
      expect(s.current?.status, SafetyCheckStatus.pending);
    });
  });

  group('after a restart', () {
    test('a running check resumes with the time it has left', () async {
      final SafetyCheckService first = service();
      final JourneyModel j = await active();
      await detect(first, incident(j));
      await first.dispose();
      services.remove(first);

      now = now.add(const Duration(seconds: 5));
      final SafetyCheckService second = service();
      await second.recover();
      expect(second.current?.status, SafetyCheckStatus.pending);
      await advance(second, const Duration(seconds: 10));
      expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
    });

    test('an overdue check times out at once', () async {
      final SafetyCheckService first = service();
      final JourneyModel j = await active();
      await detect(first, incident(j));
      await first.dispose();
      services.remove(first);

      now = now.add(const Duration(minutes: 10));
      final SafetyCheckService second = service();
      await second.recover();
      expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
      expect(checks, isNotNull);
    });

    test('a check left half-handed-over is finished', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await incidents.put(
        incident(j, status: IncidentStatus.awaitingConfirmation),
      );
      await checks.put(
        SafetyCheck(
          id: 'e1-check',
          incidentId: 'e1',
          journeyId: j.id,
          uid: 'sara',
          status: SafetyCheckStatus.timedOut,
          startedAt: now.subtract(const Duration(seconds: 30)),
          deadline: now.subtract(const Duration(seconds: 15)),
          timedOutAt: now.subtract(const Duration(seconds: 15)),
        ),
      );
      await s.recover();
      expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
      expect(stored('e1').status, IncidentStatus.escalationReady);
    });
  });

  group('cancelled', () {
    for (final (String how, Future<void> Function(String) end)
        in <(String, Future<void> Function(String))>[
          ('completed', (String id) async => journeys.complete(id)),
          ('cancelled', (String id) async => journeys.cancel(id)),
        ]) {
      test('the journey $how: cancelled, never escalated', () async {
        final SafetyCheckService s = service();
        final JourneyModel j = await active();
        await detect(s, incident(j));
        await end(j.id);
        await pumpEventQueue();
        await s.idle;
        final SafetyCheck c = checks.all.single;
        expect(c.status, SafetyCheckStatus.cancelled);
        expect(c.cancelReason, SafetyCheckCancelReason.journeyEnded);
        expect(stored('e1').status, IncidentStatus.resolved);
        expect(stored('e1').resolution, IncidentResolution.checkCancelled);
        expect(s.current, isNull);
        await advance(s, const Duration(minutes: 1));
        expect(checks.all.single.status, SafetyCheckStatus.cancelled);
      });
    }

    test('signing out cancels it; nothing is shown', () async {
      final SafetyCheckService s = service();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      session.uid = null;
      session.changed.add(null);
      await pumpEventQueue();
      await s.idle;
      expect(checks.all.single.status, SafetyCheckStatus.cancelled);
      expect(checks.all.single.cancelReason, SafetyCheckCancelReason.signedOut);
      expect(s.current, isNull);
    });

    test('an old journey\'s event never asks during a new one', () async {
      final SafetyCheckService s = service();
      final JourneyModel old = await active('Old');
      await journeys.complete(old.id);
      await active('New');
      await detect(s, incident(old));
      expect(checks.all, isEmpty);
    });
  });

  group('the state machine', () {
    test('only the drawn moves are allowed', () {
      const SafetyCheckStatus p = SafetyCheckStatus.pending;
      const SafetyCheckStatus ok = SafetyCheckStatus.confirmedSafe;
      const SafetyCheckStatus out = SafetyCheckStatus.timedOut;
      const SafetyCheckStatus ready = SafetyCheckStatus.escalationReady;
      const SafetyCheckStatus off = SafetyCheckStatus.cancelled;
      expect(p.canMoveTo(ok) && p.canMoveTo(out) && p.canMoveTo(off), isTrue);
      expect(out.canMoveTo(ready), isTrue);
      expect(ok.canMoveTo(out), isFalse, reason: 'confirmed never times out');
      expect(out.canMoveTo(ok), isFalse, reason: 'timed out never confirms');
      expect(
        off.canMoveTo(ready),
        isFalse,
        reason: 'cancelled never escalates',
      );
      expect(off.canMoveTo(out), isFalse);
      expect(ready.canMoveTo(ok), isFalse);
      expect(p.canMoveTo(ready), isFalse, reason: 'only through a timeout');
      for (final SafetyCheckStatus s in <SafetyCheckStatus>[ok, off, ready]) {
        expect(s.isFinal, isTrue);
      }
    });
  });

  group('the file store', () {
    late Directory root;
    late FileSafetyCheckRepository repo;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('checks');
      repo = FileSafetyCheckRepository(root: () async => root);
    });
    tearDown(() => root.delete(recursive: true));

    SafetyCheck check(String id, {String uid = 'sara'}) => SafetyCheck(
      id: id,
      incidentId: 'e-$id',
      journeyId: 'j1',
      uid: uid,
      status: SafetyCheckStatus.pending,
      startedAt: DateTime.utc(2026, 11, 3, 9),
      deadline: DateTime.utc(2026, 11, 3, 9, 0, 15),
    );

    test('survives a new store (an app restart); replaces by id', () async {
      await repo.put(check('a'));
      await repo.put(
        check('a').copyWith(
          status: SafetyCheckStatus.confirmedSafe,
          confirmedAt: DateTime.utc(2026, 11, 3, 9, 0, 3),
        ),
      );
      final List<SafetyCheck> again = await FileSafetyCheckRepository(
        root: () async => root,
      ).forUser('sara');
      expect(again.single.status, SafetyCheckStatus.confirmedSafe);
      expect(again.single.confirmedAt, DateTime.utc(2026, 11, 3, 9, 0, 3));
    });

    test('each account sees only its own', () async {
      await repo.put(check('a'));
      await repo.put(check('b', uid: 'omar'));
      expect((await repo.forUser('sara')).single.id, 'a');
      expect((await repo.forUser('omar')).single.id, 'b');
    });

    test('a damaged file reads as nothing', () async {
      await File(
        '${root.path}/safety_checks/sara.json',
      ).create(recursive: true).then((File f) => f.writeAsString('[{'));
      expect(await repo.forUser('sara'), isEmpty);
    });
  });

  group('found in the final audit', () {
    late FakeSafetyNotifications notices;

    SafetyCheckService withNotices() {
      notices = FakeSafetyNotifications();
      final SafetyCheckService s = SafetyCheckService(
        incidents: incidents,
        checks: checks,
        journeys: journeys,
        session: session,
        notifications: notices,
        inForeground: () => false,
        clock: () => now,
        timer: timers.call,
      );
      services.add(s);
      return s;
    }

    test('a tap waiting at the deadline wins over the timer', () async {
      final SafetyCheckService s = withNotices();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      // Written by the action's isolate just before the deadline; the app
      // has not been told yet when its timer fires.
      notices.inbox[checks.all.single.id] = now.add(
        const Duration(seconds: 14),
      );
      await advance(s, const Duration(seconds: 15));
      expect(checks.all.single.status, SafetyCheckStatus.confirmedSafe);
    });

    test('a failed write leaves the check with a timer', () async {
      final SafetyCheckService s = withNotices();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      checks.failure = StateError('disk full');
      await advance(s, const Duration(seconds: 15));
      expect(checks.all.single.status, SafetyCheckStatus.pending);
      expect(timers.pending, 1);

      checks.failure = null;
      await advance(s, SafetyCheckService.writeRetry);
      expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
    });

    test('forgetting stops the countdown and writes nothing', () async {
      final SafetyCheckService s = withNotices();
      final JourneyModel j = await active();
      await detect(s, incident(j));
      final int writes = checks.writes;
      await s.forget();
      await s.idle;
      expect(s.current, isNull);
      expect(timers.pending, 0);
      await advance(s, const Duration(seconds: 20));
      expect(checks.writes, writes);
    });
  });
}
