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
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_notice_cubit.dart';

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
  late _Session session;
  late FirestoreJourneyRepository journeys;
  late MemoryIncidentRepository incidents;
  late MemorySafetyCheckRepository checks;
  late FakeSafetyNotifications notices;
  late FakeTimers timers;
  late DateTime now;
  late bool foreground;
  late SafetyCheckService service;
  late JourneyModel journey;

  SafetyCheckService make() => SafetyCheckService(
    incidents: incidents,
    checks: checks,
    journeys: journeys,
    session: session,
    notifications: notices,
    inForeground: () => foreground,
    clock: () => now,
    timer: timers.call,
  );

  setUp(() async {
    session = _Session();
    journeys = FirestoreJourneyRepository(FakeFirebaseFirestore(), session);
    incidents = MemoryIncidentRepository();
    checks = MemorySafetyCheckRepository();
    notices = FakeSafetyNotifications();
    now = DateTime.utc(2026, 11, 4, 9);
    timers = FakeTimers(() => now);
    foreground = false;
    service = make();
    journey = await journeys.plan(
      origin: 'Home',
      destination: 'Work',
      departsAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await journeys.start(
      journey.id,
      checklistVersion: 1,
      confirmed: JourneyChecklist.itemsOf(1).toSet(),
    );
  });

  tearDown(() => service.dispose());

  Future<void> settled() async {
    await pumpEventQueue();
    await service.idle;
    await pumpEventQueue();
  }

  Future<void> detect() async {
    await incidents.put(
      PotentialIncident(
        id: 'e1',
        journeyId: journey.id,
        uid: 'sara',
        type: IncidentType.prolongedStop,
        status: IncidentStatus.detected,
        confidence: IncidentConfidence.medium,
        detectedAt: now,
        updatedAt: now,
        reason: 'test',
      ),
    );
    await settled();
  }

  Future<void> expire() async {
    now = now.add(const Duration(seconds: 15));
    timers.fireDue();
    await settled();
  }

  test('off screen, a check is a notification', () async {
    await detect();
    expect(notices.log, <String>['e1-check']);
  });

  test('on screen, the prompt is enough: no notification', () async {
    foreground = true;
    await detect();
    expect(notices.log, isEmpty);
    expect(service.current?.status, SafetyCheckStatus.pending);
  });

  test(
    'leaving the app moves the question to a notification, and back',
    () async {
      foreground = true;
      await detect();
      foreground = false;
      await service.foregroundChanged();
      expect(notices.log, <String>['e1-check']);
      foreground = true;
      await service.recover();
      await settled();
      expect(notices.log, <String>['e1-check', 'clear']);
    },
  );

  test('no check is ever posted twice', () async {
    await detect();
    await service.foregroundChanged();
    await service.foregroundChanged();
    await service.recover();
    await settled();
    expect(notices.log, <String>['e1-check']);
  });

  test('"I\'m safe" on the notification confirms the check', () async {
    await detect();
    now = now.add(const Duration(seconds: 4));
    notices.tapSafe('e1-check', now);
    await settled();
    final SafetyCheck c = checks.all.single;
    expect(c.status, SafetyCheckStatus.confirmedSafe);
    expect(c.confirmedAt, now);
    expect(incidents.all.single.status, IncidentStatus.dismissed);
    expect(service.current, isNull);
    expect(notices.log.last, 'clear');
    expect(timers.pending, 0);
  });

  test('a tap in time counts even if it is read after the deadline', () async {
    await detect();
    final DateTime tapped = now.add(const Duration(seconds: 10));
    now = now.add(const Duration(minutes: 3));
    notices.inbox['e1-check'] = tapped;
    await service.recover();
    await settled();
    expect(checks.all.single.status, SafetyCheckStatus.confirmedSafe);
    expect(checks.all.single.confirmedAt, tapped);
  });

  test(
    'a process killed mid-check: the tap survives to the next launch',
    () async {
      await detect();
      await service.dispose();
      notices.inbox['e1-check'] = now.add(const Duration(seconds: 2));
      now = now.add(const Duration(hours: 1));
      service = make();
      await service.recover();
      await settled();
      expect(checks.all.single.status, SafetyCheckStatus.confirmedSafe);
    },
  );

  test('a tap after the deadline does not undo it', () async {
    await detect();
    now = now.add(const Duration(seconds: 15));
    notices.tapSafe('e1-check', now);
    await settled();
    expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
  });

  test('a tap for an unknown or finished check is ignored', () async {
    await detect();
    notices.tapSafe('nope', now);
    await settled();
    expect(checks.all.single.status, SafetyCheckStatus.pending);
    await expire();
    notices.tapSafe('e1-check', now);
    await settled();
    expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
  });

  test('expiry replaces the question with "no answer"', () async {
    await detect();
    await expire();
    expect(notices.log, <String>['e1-check', 'noAnswer']);
  });

  test('coming back after expiry shows the note, not a notification', () async {
    await detect();
    await expire();
    foreground = true;
    await service.recover();
    await settled();
    expect(notices.log.last, 'clear');
    expect(service.current?.status, SafetyCheckStatus.escalationReady);
  });

  test('the journey completing removes the notification', () async {
    await detect();
    await journeys.complete(journey.id);
    await settled();
    expect(checks.all.single.status, SafetyCheckStatus.cancelled);
    expect(notices.log.last, 'clear');
  });

  test('signing out removes the notification', () async {
    await detect();
    session
      ..uid = null
      ..changed.add(null);
    await settled();
    expect(checks.all.single.status, SafetyCheckStatus.cancelled);
    expect(notices.log.last, 'clear');
  });

  test('the countdown does not depend on notifications working', () async {
    notices.broken = true;
    await detect();
    expect(service.current?.status, SafetyCheckStatus.pending);
    await expire();
    expect(checks.all.single.status, SafetyCheckStatus.escalationReady);
  });

  group('permission', () {
    test('blocked: reported; asking first, then the settings', () async {
      notices.now = SafetyNoticeAccess.blocked;
      final SafetyNoticeCubit cubit = SafetyNoticeCubit(notices);
      await cubit.refresh();
      expect(cubit.state, SafetyNoticeAccess.blocked);
      await cubit.allow();
      expect(notices.asked, 1);
      expect(notices.settingsOpened, 1);
      await cubit.close();
    });

    test('allowed at the prompt: no settings', () async {
      notices
        ..now = SafetyNoticeAccess.blocked
        ..afterAsking = SafetyNoticeAccess.allowed;
      final SafetyNoticeCubit cubit = SafetyNoticeCubit(notices);
      await cubit.allow();
      expect(cubit.state, SafetyNoticeAccess.allowed);
      expect(notices.settingsOpened, 0);
      await cubit.close();
    });

    test('back from the settings, it looks again', () async {
      notices.now = SafetyNoticeAccess.blocked;
      final SafetyNoticeCubit cubit = SafetyNoticeCubit(notices);
      await cubit.refresh();
      notices.now = SafetyNoticeAccess.allowed;
      await cubit.refresh();
      expect(cubit.state, SafetyNoticeAccess.allowed);
      await cubit.close();
    });
  });

  group('SafetyAnswerInbox', () {
    late Directory root;
    late SafetyAnswerInbox inbox;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('answers');
      inbox = SafetyAnswerInbox(root: () async => root);
    });

    tearDown(() => root.delete(recursive: true));

    test('an answer is read once, with its time', () async {
      final DateTime at = DateTime.utc(2026, 11, 4, 9, 0, 7);
      await inbox.put('e1-check', at);
      expect(await inbox.take(), <String, DateTime>{'e1-check': at});
      expect(await inbox.take(), isEmpty);
    });

    test('nothing yet: nothing to read', () async {
      expect(await inbox.take(), isEmpty);
    });

    test('a damaged answer is dropped', () async {
      final File bad = File('${root.path}/safety_checks/answers/x')
        ..createSync(recursive: true)
        ..writeAsStringSync('not a time');
      expect(await inbox.take(), isEmpty);
      expect(bad.existsSync(), isFalse);
    });

    test('an id that could leave the directory is refused', () async {
      expect(
        () => inbox.put('../../evil', DateTime.utc(2026)),
        throwsArgumentError,
      );
    });
  });
}
