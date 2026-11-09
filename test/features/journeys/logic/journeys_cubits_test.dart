import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_start_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/plan_journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_start_state.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_state.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';
import 'package:safe_ride/features/journeys/logic/states/plan_journey_state.dart';

JourneyModel _journey(
  String id, [
  JourneyStatus status = JourneyStatus.planned,
]) => JourneyModel(
  id: id,
  origin: 'Home',
  destination: 'Work',
  status: status,
  departsAt: DateTime.utc(2026, 2),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final JourneyDraft _draft = JourneyDraft(
  origin: 'Home',
  destination: 'Work',
  departsAt: DateTime.utc(2026, 11),
);

class _Session implements SessionReader {
  String fullName = 'Abdel Rahman Ali';
  final StreamController<void> renamed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => renamed.stream;

  @override
  Future<SessionUser?> signedInUser() async =>
      SessionUser(id: 'sara@example.com', fullName: fullName);
}

/// An in-memory repository whose calls can be made to fail or to wait.
class _Repository extends Fake implements JourneyRepository {
  final List<JourneyModel> all = <JourneyModel>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  JourneyFailure? failure;
  Completer<void>? gate;
  int plans = 0;
  int starts = 0;
  bool synced = true;

  Future<void> _maybe() async {
    final Completer<void>? wait = gate;
    if (wait != null) await wait.future;
    final JourneyFailure? f = failure;
    if (f != null) throw f;
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<JourneyModel>> journeys() async {
    await _maybe();
    return List<JourneyModel>.of(all);
  }

  @override
  Future<JourneyModel?> journey(String id) async {
    await _maybe();
    return all.where((JourneyModel j) => j.id == id).firstOrNull;
  }

  @override
  Future<JourneyModel> plan({
    required String origin,
    required String destination,
    required DateTime departsAt,
    JourneyPlace? originPlace,
    JourneyPlace? destinationPlace,
    double? plannedDistanceMeters,
    double? plannedDurationSeconds,
  }) async {
    plans++;
    await _maybe();
    final JourneyModel j = _journey('j$plans');
    all.insert(0, j);
    _changes.add(null);
    return j;
  }

  @override
  Future<({JourneyModel journey, bool synced})> start(
    String id, {
    required int checklistVersion,
    required Set<String> confirmed,
  }) async {
    starts++;
    await _maybe();
    final JourneyModel started = all
        .firstWhere((JourneyModel j) => j.id == id)
        .copyWith(status: JourneyStatus.active);
    all[all.indexWhere((JourneyModel j) => j.id == id)] = started;
    return (journey: started, synced: synced);
  }

  @override
  Future<JourneyModel> complete(String id) async {
    await _maybe();
    final JourneyModel done = all
        .firstWhere((JourneyModel j) => j.id == id)
        .copyWith(status: JourneyStatus.completed);
    all[all.indexWhere((JourneyModel j) => j.id == id)] = done;
    return done;
  }
}

void main() {
  test(
    'JourneysCubit: the journeys and a first name, reloaded on change',
    () async {
      final _Repository repository = _Repository();
      final JourneysCubit cubit = JourneysCubit(repository, _Session());

      await cubit.load();
      expect(
        cubit.state,
        const JourneysReady(
          journeys: <JourneyModel>[],
          firstName: 'Abdel Rahman',
        ),
      );

      await repository.plan(
        origin: 'Home',
        destination: 'Work',
        departsAt: DateTime.utc(2026, 11),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as JourneysReady).journeys, hasLength(1));
      await cubit.close();
    },
  );

  test('JourneysCubit: a renamed account greets by its new name', () async {
    final _Session session = _Session();
    final JourneysCubit cubit = JourneysCubit(_Repository(), session);
    await cubit.load();

    session
      ..fullName = 'Sara Al-Harbi'
      ..renamed.add(null);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as JourneysReady).firstName, 'Sara');
    await cubit.close();
  });

  test('JourneysCubit: a failure keeps the greeting', () async {
    final _Repository repository = _Repository()
      ..failure = const JourneyFailure(JourneyFailureCode.storage);
    final JourneysCubit cubit = JourneysCubit(repository, _Session());

    await cubit.load();
    expect(
      cubit.state,
      const JourneysFailed(
        JourneyFailureCode.storage,
        firstName: 'Abdel Rahman',
      ),
    );
    await cubit.close();
  });

  test('PlanJourneyCubit: one save, however many taps', () async {
    final _Repository repository = _Repository()..gate = Completer<void>();
    final PlanJourneyCubit cubit = PlanJourneyCubit(repository);

    final Future<void> first = cubit.confirm(_draft);
    await cubit.confirm(_draft);
    expect(cubit.state, const PlanJourneySaving());
    repository.gate!.complete();
    await first;
    await cubit.confirm(_draft);

    expect(repository.plans, 1);
    expect(cubit.state, isA<PlanJourneySaved>());
    await cubit.close();
  });

  test('PlanJourneyCubit: a failure can be retried', () async {
    final _Repository repository = _Repository()
      ..failure = const JourneyFailure(JourneyFailureCode.storage);
    final PlanJourneyCubit cubit = PlanJourneyCubit(repository);

    await cubit.confirm(_draft);
    expect(cubit.state, const PlanJourneyFailed(JourneyFailureCode.storage));
    repository.failure = null;
    await cubit.confirm(_draft);
    expect(cubit.state, isA<PlanJourneySaved>());
    await cubit.close();
  });

  test('JourneyCubit: missing, then a completion with a busy step', () async {
    final _Repository repository = _Repository()..all.add(_journey('a'));
    final JourneyCubit cubit = JourneyCubit(repository);

    await cubit.load('nope');
    expect(cubit.state, const JourneyMissing());

    await cubit.load('a');
    final Future<List<JourneyState>> states = cubit.stream.take(2).toList();
    await cubit.complete();
    final List<JourneyState> seen = await states;
    expect(seen.first, JourneyReady(_journey('a'), busy: true));
    expect((seen.last as JourneyReady).journey.status, JourneyStatus.completed);
    await cubit.close();
  });

  test('JourneyCubit: a failed change keeps the journey on screen', () async {
    final _Repository repository = _Repository()..all.add(_journey('a'));
    final JourneyCubit cubit = JourneyCubit(repository);
    await cubit.load('a');
    repository.failure = const JourneyFailure(JourneyFailureCode.storage);

    await cubit.complete();
    expect(
      cubit.state,
      JourneyFailed(JourneyFailureCode.storage, journey: _journey('a')),
    );
    await cubit.close();
  });

  group('JourneyStartCubit', () {
    final List<String> items = JourneyStartCubit.items;

    Future<(JourneyStartCubit, _Repository)> open([
      JourneyStatus status = JourneyStatus.planned,
    ]) async {
      final _Repository repository = _Repository()
        ..all.add(_journey('a', status));
      final JourneyStartCubit cubit = JourneyStartCubit(repository);
      addTearDown(cubit.close);
      await cubit.load('a');
      return (cubit, repository);
    }

    Set<String> confirmed(JourneyStartCubit cubit) => switch (cubit.state) {
      JourneyStartFilling(:final Set<String> confirmed) ||
      JourneyStartFailed(:final Set<String> confirmed) => confirmed,
      _ => throw StateError('no checklist: ${cubit.state}'),
    };

    test('every item starts unconfirmed, and toggles', () async {
      final (JourneyStartCubit cubit, _) = await open();
      expect(items, hasLength(9));
      expect(confirmed(cubit), isEmpty);

      cubit.toggle(items.first);
      expect(confirmed(cubit), <String>{items.first});
      cubit.toggle(items.first);
      expect(confirmed(cubit), isEmpty);
      cubit.toggle('notAnItem');
      expect(confirmed(cubit), isEmpty);
    });

    test('an incomplete checklist starts nothing', () async {
      final (JourneyStartCubit cubit, _Repository repository) = await open();
      items.skip(1).forEach(cubit.toggle);

      await cubit.start();
      expect(repository.starts, 0);
      expect(cubit.state, isA<JourneyStartFilling>());
    });

    test('one start, however many taps; nothing changes meanwhile', () async {
      final (JourneyStartCubit cubit, _Repository repository) = await open();
      items.forEach(cubit.toggle);
      repository.gate = Completer<void>();

      final Future<void> first = cubit.start();
      await cubit.start();
      cubit.toggle(items.first);
      expect(
        cubit.state,
        isA<JourneyStartFilling>()
            .having((JourneyStartFilling s) => s.starting, 'starting', isTrue)
            .having(
              (JourneyStartFilling s) => s.confirmed,
              'confirmed',
              items.toSet(),
            ),
      );
      repository.gate!.complete();
      await first;
      await cubit.start();

      expect(repository.starts, 1);
      expect(
        cubit.state,
        isA<JourneyStartStarted>().having(
          (JourneyStartStarted s) => s.synced,
          'synced',
          isTrue,
        ),
      );
    });

    test('saved only on the phone, it says so', () async {
      final (JourneyStartCubit cubit, _Repository repository) = await open();
      repository.synced = false;
      items.forEach(cubit.toggle);
      await cubit.start();
      expect((cubit.state as JourneyStartStarted).synced, isFalse);
    });

    test('a failed start keeps the answers for a retry', () async {
      final (JourneyStartCubit cubit, _Repository repository) = await open();
      items.forEach(cubit.toggle);
      repository.failure = const JourneyFailure(JourneyFailureCode.network);

      await cubit.start();
      expect(cubit.state, isA<JourneyStartFailed>());
      expect(confirmed(cubit), items.toSet());

      repository.failure = null;
      await cubit.start();
      expect(cubit.state, isA<JourneyStartStarted>());
    });

    test('started elsewhere meanwhile, this checklist is over', () async {
      final (JourneyStartCubit cubit, _Repository repository) = await open();
      items.forEach(cubit.toggle);
      repository.failure = const JourneyFailure(
        JourneyFailureCode.alreadyStarted,
      );
      await cubit.start();
      expect(
        cubit.state,
        const JourneyStartUnavailable(JourneyFailureCode.alreadyStarted),
      );
    });

    test('only a planned journey gets a checklist', () async {
      expect(
        (await open(JourneyStatus.active)).$1.state,
        const JourneyStartUnavailable(JourneyFailureCode.alreadyStarted),
      );
      expect(
        (await open(JourneyStatus.completed)).$1.state,
        const JourneyStartUnavailable(JourneyFailureCode.notPlanned),
      );
      final JourneyStartCubit missing = JourneyStartCubit(_Repository());
      addTearDown(missing.close);
      await missing.load('nope');
      expect(
        missing.state,
        const JourneyStartUnavailable(JourneyFailureCode.notFound),
      );
    });
  });
}
