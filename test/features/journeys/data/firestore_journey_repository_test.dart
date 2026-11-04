import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';

/// Signed in as [uid], or signed out when it is null.
class _Session implements SessionReader {
  _Session(this.uid);

  String? uid;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

final List<String> _all = JourneyChecklist.itemsOf(1);

String _checklistOf(String id) =>
    'users/sara/journeys/$id/checklists/preJourney';

Matcher _fails(JourneyFailureCode code) => throwsA(
  isA<JourneyFailure>().having((JourneyFailure f) => f.code, 'code', code),
);

void main() {
  late FakeFirebaseFirestore db;
  late _Session session;
  late FirestoreJourneyRepository repository;
  final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    db = FakeFirebaseFirestore();
    session = _Session('sara');
    repository = FirestoreJourneyRepository(db, session);
  });

  Future<JourneyModel> plan(String to) =>
      repository.plan(origin: '  Home ', destination: to, departsAt: tomorrow);

  Future<({JourneyModel journey, bool synced})> start(
    String id, {
    int version = JourneyChecklist.current,
    Set<String>? confirmed,
  }) => repository.start(
    id,
    checklistVersion: version,
    confirmed: confirmed ?? _all.toSet(),
  );

  test('a confirmed plan is stored under the account, as planned', () async {
    final JourneyModel j = await plan('Work');

    expect(j.status, JourneyStatus.planned);
    expect(j.origin, 'Home');
    final Map<String, dynamic> stored =
        (await db.doc('users/sara/journeys/${j.id}').get()).data()!;
    expect(
      stored.keys,
      unorderedEquals(<String>[
        'origin',
        'destination',
        'departsAt',
        'status',
        'createdAt',
        'updatedAt',
      ]),
    );
    expect(stored['status'], 'planned');
    expect((await repository.journeys()).single.id, j.id);
  });

  test('journeys come newest first', () async {
    await plan('First');
    // Server times a few milliseconds apart, as two taps would be.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await plan('Second');
    final List<JourneyModel> all = await repository.journeys();
    expect(all.map((JourneyModel j) => j.destination), <String>[
      'Second',
      'First',
    ]);
  });

  test('a planned journey is edited; started, it is not; closed, it never '
      'changes again', () async {
    final JourneyModel j = await plan('Work');
    final JourneyModel edited = await repository.update(
      j.id,
      origin: 'Office',
      destination: 'Gym',
      departsAt: tomorrow,
    );
    expect(edited.destination, 'Gym');
    expect((await repository.journey(j.id))?.destination, 'Gym');
    expect(repository.complete(j.id), _fails(JourneyFailureCode.notStarted));

    await start(j.id);
    expect(
      repository.update(
        j.id,
        origin: 'A',
        destination: 'B',
        departsAt: tomorrow,
      ),
      _fails(JourneyFailureCode.alreadyStarted),
    );

    await repository.complete(j.id);
    expect((await repository.journey(j.id))?.status, JourneyStatus.completed);
    expect(repository.cancel(j.id), _fails(JourneyFailureCode.notPlanned));
    expect(start(j.id), _fails(JourneyFailureCode.notPlanned));
    expect(
      repository.update(
        j.id,
        origin: 'A',
        destination: 'B',
        departsAt: tomorrow,
      ),
      _fails(JourneyFailureCode.notPlanned),
    );
  });

  group('starting a journey', () {
    test('only with the whole checklist; nothing is saved before', () async {
      final JourneyModel j = await plan('Work');

      for (final Set<String> partial in <Set<String>>{
        const <String>{},
        _all.skip(1).toSet(),
        <String>{..._all, 'notAnItem'},
      }) {
        expect(
          start(j.id, confirmed: partial),
          _fails(JourneyFailureCode.checklistIncomplete),
        );
      }
      expect(
        start(j.id, version: 99),
        _fails(JourneyFailureCode.checklistIncomplete),
      );

      expect((await repository.journey(j.id))?.status, JourneyStatus.planned);
      expect((await db.doc(_checklistOf(j.id)).get()).exists, isFalse);
    });

    test('saves the checklist record with the start, together', () async {
      final JourneyModel j = await plan('Work');
      final ({JourneyModel journey, bool synced}) started = await start(j.id);

      expect(started.synced, isTrue);
      expect(started.journey.status, JourneyStatus.active);
      expect(started.journey.startedAt, isNotNull);
      final JourneyModel? stored = await repository.journey(j.id);
      expect(stored?.status, JourneyStatus.active);
      expect(stored?.startedAt, isNotNull);

      final Map<String, dynamic> record =
          (await db.doc(_checklistOf(j.id)).get()).data()!;
      expect(record['journeyId'], j.id);
      expect(record['uid'], 'sara');
      expect(record['version'], 1);
      expect(record['items'], _all);
      expect(record['complete'], isTrue);
      expect(record['completedAt'], isNotNull);
    });

    test('happens once', () async {
      final JourneyModel j = await plan('Work');
      await start(j.id);
      expect(start(j.id), _fails(JourneyFailureCode.alreadyStarted));
    });

    test('each journey has its own checklist', () async {
      final JourneyModel first = await plan('Work');
      final JourneyModel second = await plan('Gym');
      await start(first.id);

      expect(
        (await repository.journey(second.id))?.status,
        JourneyStatus.planned,
      );
      expect((await db.doc(_checklistOf(second.id)).get()).exists, isFalse);
    });

    test("never another account's journey", () async {
      final JourneyModel saras = await plan('Work');
      session.uid = 'omar';
      await expectLater(start(saras.id), _fails(JourneyFailureCode.notFound));
      session.uid = 'sara';
      expect(
        (await repository.journey(saras.id))?.status,
        JourneyStatus.planned,
      );
    });

    test('an active journey is completed or cancelled', () async {
      final JourneyModel a = await plan('Work');
      final JourneyModel b = await plan('Gym');
      await start(a.id);
      await start(b.id);

      expect((await repository.complete(a.id)).status, JourneyStatus.completed);
      expect((await repository.cancel(b.id)).status, JourneyStatus.cancelled);
    });
  });

  test('an unknown id is not found', () async {
    expect(await repository.journey('nope'), isNull);
    expect(repository.cancel('nope'), _fails(JourneyFailureCode.notFound));
  });

  test('each account sees only its own journeys', () async {
    final JourneyModel saras = await plan('Work');

    session.uid = 'omar';
    expect(await repository.journeys(), isEmpty);
    expect(await repository.journey(saras.id), isNull);
    expect(repository.cancel(saras.id), _fails(JourneyFailureCode.notFound));

    session.uid = 'sara';
    expect((await repository.journeys()).single.id, saras.id);
  });

  test('signed out, there is no account to read or write', () async {
    session.uid = null;
    expect(repository.journeys(), _fails(JourneyFailureCode.signedOut));
    expect(plan('Work'), _fails(JourneyFailureCode.signedOut));
  });

  test('every change is announced, so open screens reload', () async {
    await repository.journeys();
    int changes = 0;
    final StreamSubscription<void> listening = repository.changes.listen(
      (_) => changes++,
    );
    final JourneyModel j = await plan('Work');
    await repository.cancel(j.id);
    await Future<void>.delayed(Duration.zero);

    expect(changes, greaterThanOrEqualTo(2));
    await listening.cancel();
  });
}
