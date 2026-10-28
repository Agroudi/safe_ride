import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/local_journey_repository.dart';

/// Whoever [user] says is signed in.
class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  SessionUser? user = const SessionUser(
    id: 'sara@example.com',
    fullName: 'Sara',
  );

  @override
  Future<SessionUser?> signedInUser() async => user;
}

Matcher _fails(JourneyFailureCode code) => throwsA(
  isA<JourneyFailure>().having((JourneyFailure f) => f.code, 'code', code),
);

void main() {
  late _Session session;
  late DateTime now;
  late LocalJourneyRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    session = _Session();
    now = DateTime.utc(2026, 10, 28, 9);
    repository = LocalJourneyRepository(
      const FlutterSecureStorage(),
      session,
      clock: () => now,
    );
  });

  Future<JourneyModel> plan(String from, String to) {
    now = now.add(const Duration(minutes: 1));
    return repository.plan(
      origin: from,
      destination: to,
      departsAt: now.add(const Duration(hours: 1)),
    );
  }

  test('a confirmed plan is saved as planned, trimmed, newest first', () async {
    await plan('Home', 'Work');
    final JourneyModel second = await plan('  Work ', ' Gym  ');

    final List<JourneyModel> all = await repository.journeys();
    expect(all.map((JourneyModel j) => j.destination), <String>['Gym', 'Work']);
    expect(all.first, second);
    expect(second.origin, 'Work');
    expect(second.status, JourneyStatus.planned);
    expect(second.createdAt, second.updatedAt);
    expect(await repository.journey(second.id), second);
  });

  test('ids are unique', () async {
    final Set<String> ids = <String>{
      for (int i = 0; i < 20; i++) (await plan('A$i', 'B$i')).id,
    };
    expect(ids, hasLength(20));
  });

  test('complete and cancel close a planned journey, once', () async {
    final JourneyModel a = await plan('Home', 'Work');
    final JourneyModel b = await plan('Work', 'Home');

    now = now.add(const Duration(hours: 1));
    final JourneyModel done = await repository.complete(a.id);
    expect(done.status, JourneyStatus.completed);
    expect(done.updatedAt, now);
    expect((await repository.cancel(b.id)).status, JourneyStatus.cancelled);

    expect(repository.cancel(a.id), _fails(JourneyFailureCode.notPlanned));
    expect(repository.complete(b.id), _fails(JourneyFailureCode.notPlanned));
    expect(repository.complete('nope'), _fails(JourneyFailureCode.notFound));
  });

  test('each account sees only its own journeys', () async {
    await plan('Home', 'Work');
    session.user = const SessionUser(id: 'omar@example.com', fullName: 'Omar');

    expect(await repository.journeys(), isEmpty);
    await plan('Club', 'Park');
    expect(await repository.journeys(), hasLength(1));

    session.user = const SessionUser(id: 'sara@example.com', fullName: 'Sara');
    expect((await repository.journeys()).single.destination, 'Work');
  });

  test('signed out, there is no account to read or write', () async {
    session.user = null;
    expect(repository.journeys(), _fails(JourneyFailureCode.signedOut));
    expect(
      repository.plan(origin: 'A', destination: 'B', departsAt: now),
      _fails(JourneyFailureCode.signedOut),
    );
  });

  test(
    'history keeps the newest ${LocalJourneyRepository.maxJourneys}',
    () async {
      for (int i = 0; i < LocalJourneyRepository.maxJourneys + 5; i++) {
        await plan('From $i', 'To $i');
      }
      final List<JourneyModel> all = await repository.journeys();
      expect(all, hasLength(LocalJourneyRepository.maxJourneys));
      expect(
        all.first.destination,
        'To ${LocalJourneyRepository.maxJourneys + 4}',
      );
    },
  );

  test('every change is announced, so open screens reload', () async {
    final List<void> seen = <void>[];
    repository.changes.listen(seen.add);
    final JourneyModel j = await plan('Home', 'Work');
    await repository.complete(j.id);
    await Future<void>.delayed(Duration.zero);
    expect(seen, hasLength(2));
  });

  test('a corrupt store is a storage failure, never a crash', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      LocalJourneyRepository.keyFor('sara@example.com'): '{not a list',
    });
    expect(repository.journeys(), _fails(JourneyFailureCode.storage));
  });

  test(
    'a plan keeps its departure; an edit changes a planned journey only',
    () async {
      final JourneyModel j = await plan('Home', 'Work');
      expect(j.departsAt, now.add(const Duration(hours: 1)));

      now = now.add(const Duration(minutes: 5));
      final DateTime later = now.add(const Duration(days: 1));
      final JourneyModel edited = await repository.update(
        j.id,
        origin: ' Office ',
        destination: 'Airport',
        departsAt: later,
      );
      expect(edited.origin, 'Office');
      expect(edited.destination, 'Airport');
      expect(edited.departsAt, later);
      expect(edited.updatedAt, now);
      expect(edited.status, JourneyStatus.planned);

      await repository.cancel(j.id);
      expect(
        repository.update(
          j.id,
          origin: 'A',
          destination: 'B',
          departsAt: later,
        ),
        _fails(JourneyFailureCode.notPlanned),
      );
    },
  );

  // Journeys saved before departures existed must still load.
  test('a stored journey without a departure loads with none', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      LocalJourneyRepository.keyFor('sara@example.com'):
          '[{"id":"old","origin":"Home","destination":"Work",'
          '"status":"planned","createdAt":"2026-10-27T10:00:00.000Z",'
          '"updatedAt":"2026-10-27T10:00:00.000Z"}]',
    });
    final JourneyModel old = (await repository.journeys()).single;
    expect(old.departsAt, isNull);
    expect(old.origin, 'Home');
  });
}
