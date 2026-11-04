import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/escalation.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_escalation_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/logic/cubit/escalation_cubit.dart';

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
  final DateTime t0 = DateTime.utc(2026, 11, 4, 9);
  late _Session session;
  late MemoryIncidentRepository incidents;
  late MemorySafetyCheckRepository checks;
  late FakeEscalations server;
  late SafetyCheckService service;
  late EscalationSync sync;
  late DateTime now;
  late bool live;

  EscalationSync make() => EscalationSync(
    checks: checks,
    incidents: incidents,
    repository: server,
    session: session,
    updates: service.changes,
    live: live,
    clock: () => now,
  );

  setUp(() {
    session = _Session();
    incidents = MemoryIncidentRepository();
    checks = MemorySafetyCheckRepository();
    server = FakeEscalations();
    now = t0;
    live = true;
    service = SafetyCheckService(
      incidents: incidents,
      checks: checks,
      journeys: FirestoreJourneyRepository(FakeFirebaseFirestore(), session),
      session: session,
      notifications: FakeSafetyNotifications(),
      inForeground: () => true,
      clock: () => now,
    );
    sync = make();
  });

  tearDown(() async {
    await sync.dispose();
    await service.dispose();
  });

  Future<void> seed({
    String uid = 'sara',
    String id = 'e1',
    SafetyCheckStatus status = SafetyCheckStatus.escalationReady,
  }) async {
    await incidents.put(
      PotentialIncident(
        id: id,
        journeyId: 'j1',
        uid: uid,
        type: IncidentType.prolongedStop,
        status: IncidentStatus.escalationReady,
        confidence: IncidentConfidence.medium,
        detectedAt: t0,
        updatedAt: t0,
        reason: 'test',
      ),
    );
    await checks.put(
      SafetyCheck(
        id: '$id-check',
        incidentId: id,
        journeyId: 'j1',
        uid: uid,
        status: status,
        startedAt: t0,
        deadline: t0.add(const Duration(seconds: 15)),
        timedOutAt: t0.add(const Duration(seconds: 15)),
        escalationReadyAt: t0.add(const Duration(seconds: 15)),
      ),
    );
  }

  Future<void> flushed([EscalationSync? which]) async {
    await (which ?? sync).flush();
    await pumpEventQueue();
  }

  SafetyCheck check() => checks.all.single;

  test('an escalation-ready check is sent and confirmed, once', () async {
    await seed();
    now = t0.add(const Duration(minutes: 1));
    await flushed();
    await flushed();
    await flushed();
    expect(server.submitted, <String>['e1-check']);
    expect(check().escalationSyncedAt, now);
    expect(check().escalationQueuedAt, now);
  });

  test('offline: saved, not confirmed; synced on reconnect', () async {
    await seed();
    server.hold = Completer<void>();
    final DateTime queued = t0.add(const Duration(minutes: 1));
    now = queued;
    await flushed();
    expect(check().escalationQueuedAt, queued);
    expect(check().escalationSyncedAt, isNull);

    now = t0.add(const Duration(hours: 2));
    server.hold!.complete();
    await pumpEventQueue();
    expect(check().escalationQueuedAt, queued, reason: 'kept');
    expect(check().escalationSyncedAt, now);
    expect(check().timedOutAt, t0.add(const Duration(seconds: 15)));
  });

  test('flushing again while offline writes nothing more', () async {
    await seed();
    server.hold = Completer<void>();
    await flushed();
    await flushed();
    await flushed();
    expect(server.submitted, hasLength(1));
    server.hold!.complete();
    await pumpEventQueue();
  });

  test(
    'a restart while queued: the rules refuse the copy, it counts',
    () async {
      await seed();
      server.hold = Completer<void>();
      await flushed();
      await sync.dispose();

      // The first write reached the server; this run's copy is refused.
      server
        ..hold = null
        ..onServer.add('e1-check')
        ..refused = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      sync = make();
      await flushed();
      expect(check().escalationSyncedAt, isNotNull);
    },
  );

  test('a network failure leaves it to the next flush', () async {
    await seed();
    server
      ..refused = StateError('failed')
      ..unreachable = true;
    await flushed();
    expect(check().escalationSyncedAt, isNull);
    server
      ..refused = null
      ..unreachable = false;
    await flushed();
    expect(server.submitted, hasLength(2));
    expect(check().escalationSyncedAt, isNotNull);
  });

  test('only escalation-ready checks go', () async {
    await seed(status: SafetyCheckStatus.confirmedSafe);
    await seed(id: 'e2', status: SafetyCheckStatus.cancelled);
    await seed(id: 'e3', status: SafetyCheckStatus.pending);
    await flushed();
    expect(server.submitted, isEmpty);
  });

  test('another account on this phone never sends this one\'s', () async {
    await seed(uid: 'omar');
    await flushed();
    expect(server.submitted, isEmpty);
  });

  test('signed out: nothing is sent; on sign-in it goes', () async {
    await seed();
    session.uid = null;
    await flushed();
    expect(server.submitted, isEmpty);
    session
      ..uid = 'sara'
      ..changed.add(null);
    await pumpEventQueue();
    await sync.idle;
    await pumpEventQueue();
    expect(server.submitted, <String>['e1-check']);
  });

  test('a check without its incident is left alone', () async {
    await seed();
    incidents.all.clear();
    await flushed();
    expect(server.submitted, isEmpty);
  });

  group('the status shown', () {
    late EscalationCubit cubit;

    setUp(() {
      cubit = EscalationCubit(checks, server, sync, session, clock: () => now);
    });

    tearDown(() => cubit.close());

    Future<void> record(Escalation? e) async {
      server.record.add(e);
      await pumpEventQueue();
    }

    test('nothing unanswered: nothing', () async {
      await cubit.watch('j1');
      expect(cubit.state.phase, EscalationPhase.none);
    });

    test('offline, then received, then the backend\'s word alone', () async {
      await seed();
      server.hold = Completer<void>();
      await cubit.watch('j1');
      expect(cubit.state.phase, EscalationPhase.waitingForConnection);

      await flushed();
      expect(cubit.state.phase, EscalationPhase.waitingForConnection);
      server.hold!.complete();
      await pumpEventQueue();
      expect(cubit.state.phase, EscalationPhase.waitingForServer);

      await record(const Escalation(status: EscalationStatus.dispatching));
      expect(cubit.state.phase, EscalationPhase.sending);
      await record(const Escalation(status: EscalationStatus.retrying));
      expect(cubit.state.phase, EscalationPhase.sending);
      await record(
        const Escalation(
          status: EscalationStatus.completed,
          recipients: 2,
          accepted: 2,
        ),
      );
      expect(cubit.state.phase, EscalationPhase.accepted);
      expect(cubit.state.escalation?.accepted, 2);
    });

    for (final (EscalationStatus status, EscalationPhase phase)
        in <(EscalationStatus, EscalationPhase)>[
          (EscalationStatus.failed, EscalationPhase.failed),
          (EscalationStatus.noRecipients, EscalationPhase.noRecipients),
          (EscalationStatus.rejected, EscalationPhase.rejected),
        ]) {
      test('${status.name} is said as it is', () async {
        await seed();
        await cubit.watch('j1');
        await record(Escalation(status: status));
        expect(cubit.state.phase, phase);
      });
    }

    test('one journey\'s status is not another\'s', () async {
      await seed();
      await cubit.watch('other');
      expect(cubit.state.phase, EscalationPhase.none);
    });
  });

  group('with no backend (the Spark plan)', () {
    late EscalationCubit cubit;

    setUp(() async {
      await sync.dispose();
      live = false;
      sync = make();
      cubit = EscalationCubit(checks, server, sync, session, clock: () => now);
    });

    tearDown(() => cubit.close());

    test('nothing leaves the phone, and the record stays', () async {
      await seed();
      await flushed();
      await flushed();
      expect(server.submitted, isEmpty);
      expect(check().status, SafetyCheckStatus.escalationReady);
      expect(check().escalationQueuedAt, isNull);
    });

    test('it says nobody was alerted, with nothing to retry', () async {
      await seed();
      await cubit.watch('j1');
      expect(cubit.state.phase, EscalationPhase.serviceUnavailable);
      expect(cubit.state.canRetry, isFalse);
    });

    test('nothing the server could say makes it look sent', () async {
      await seed();
      await cubit.watch('j1');
      server.record.add(const Escalation(status: EscalationStatus.completed));
      await pumpEventQueue();
      expect(cubit.state.phase, EscalationPhase.serviceUnavailable);
    });

    test('retrying changes nothing and sends nothing', () async {
      await seed();
      await cubit.watch('j1');
      await cubit.retry();
      expect(server.submitted, isEmpty);
      expect(cubit.state.phase, EscalationPhase.serviceUnavailable);
    });
  });

  group('a backend that goes quiet', () {
    late EscalationCubit cubit;

    setUp(() {
      cubit = EscalationCubit(checks, server, sync, session, clock: () => now);
    });

    tearDown(() => cubit.close());

    test('a confirmed request with no answer reads as unavailable', () async {
      await seed();
      await flushed();
      await cubit.watch('j1');
      expect(cubit.state.phase, EscalationPhase.waitingForServer);
      expect(cubit.state.canRetry, isFalse);

      now = now.add(cubit.serverWait);
      await cubit.watch('j1');
      expect(cubit.state.phase, EscalationPhase.serviceUnavailable);
      expect(cubit.state.canRetry, isTrue);
    });

    test('the backend answering late still counts', () async {
      await seed();
      await flushed();
      now = now.add(cubit.serverWait);
      await cubit.watch('j1');
      server.record.add(const Escalation(status: EscalationStatus.dispatching));
      await pumpEventQueue();
      expect(cubit.state.phase, EscalationPhase.sending);
    });

    test('offline can be retried, and retrying sends again', () async {
      await seed();
      server
        ..refused = StateError('failed')
        ..unreachable = true;
      await flushed();
      await cubit.watch('j1');
      expect(cubit.state.phase, EscalationPhase.waitingForConnection);
      expect(cubit.state.canRetry, isTrue);
      server
        ..refused = null
        ..unreachable = false;
      await cubit.retry();
      await pumpEventQueue();
      expect(server.submitted, hasLength(2));
      expect(cubit.state.phase, EscalationPhase.waitingForServer);
    });
  });

  group('FirestoreEscalationRepository', () {
    late FakeFirebaseFirestore db;
    late FirestoreEscalationRepository repository;

    setUp(() {
      db = FakeFirebaseFirestore();
      repository = FirestoreEscalationRepository(db);
    });

    Future<void> submit() async {
      await seed();
      await repository.submit(check(), incidents.all.single);
    }

    test(
      'one request: the check and its incident, under the account',
      () async {
        await submit();
        final Map<String, dynamic> c =
            (await db.doc('users/sara/safetyChecks/e1-check').get()).data()!;
        expect(c['status'], 'escalationReady');
        expect(c['incidentId'], 'e1');
        expect(c['timedOutAt'], c['deadline']);
        final Map<String, dynamic> i =
            (await db.doc('users/sara/incidents/e1').get()).data()!;
        expect(i['safetyCheckId'], 'e1-check');
        expect(i['type'], 'prolongedStop');
      },
    );

    test('no location leaves the phone with it', () async {
      await seed();
      await repository.submit(
        check(),
        incidents.all.single.copyWith(lat: 24.7136, lng: 46.6753),
      );
      final Map<String, dynamic> i =
          (await db.doc('users/sara/incidents/e1').get()).data()!;
      expect(i.keys.toSet(), <String>{
        'journeyId',
        'safetyCheckId',
        'type',
        'confidence',
        'detectedAt',
        'createdAt',
      });
    });

    test('reads the backend\'s record, of this account only', () async {
      await db.doc('users/sara/escalations/e1-check').set(<String, Object?>{
        'status': 'completed',
        'recipients': 1,
        'accepted': 1,
        'reason': null,
      });
      expect(
        await repository.watch('sara', 'e1-check').first,
        const Escalation(
          status: EscalationStatus.completed,
          recipients: 1,
          accepted: 1,
        ),
      );
      expect(await repository.watch('omar', 'e1-check').first, isNull);
    });
  });
}
