import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';

/// [JourneyRepository] for the MVP: each account's journeys on **this phone
/// only**.
///
/// ⚠️ **Local only.** Nothing is synced, shared or seen by anyone else; the
/// journeys go with the app's data. Where someone travels is sensitive, so
/// they are kept in `flutter_secure_storage` (encrypted), one JSON list per
/// account under `journeys.<account id>`, newest first and capped at
/// [maxJourneys]. Signing out keeps them, as it keeps the account.
class LocalJourneyRepository implements JourneyRepository {
  LocalJourneyRepository(
    this._storage,
    this._session, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final SessionReader _session;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// The oldest journeys beyond this are dropped when a new one is saved.
  static const int maxJourneys = 200;

  static String keyFor(String accountId) => 'journeys.$accountId';

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<JourneyModel>> journeys() async => (await _load()).$2;

  @override
  Future<JourneyModel?> journey(String id) async {
    for (final JourneyModel j in (await _load()).$2) {
      if (j.id == id) return j;
    }
    return null;
  }

  @override
  Future<JourneyModel> plan({
    required String origin,
    required String destination,
    required DateTime departsAt,
  }) async {
    final (String key, List<JourneyModel> all) = await _load();
    final DateTime now = _clock().toUtc();
    final JourneyModel journey = JourneyModel(
      id: _newId(now),
      origin: origin.trim(),
      destination: destination.trim(),
      status: JourneyStatus.planned,
      createdAt: now,
      updatedAt: now,
      departsAt: departsAt.toUtc(),
    );
    await _save(
      key,
      <JourneyModel>[journey, ...all].take(maxJourneys).toList(),
    );
    return journey;
  }

  @override
  Future<JourneyModel> update(
    String id, {
    required String origin,
    required String destination,
    required DateTime departsAt,
  }) => _change(
    id,
    (JourneyModel j) => j.copyWith(
      origin: origin.trim(),
      destination: destination.trim(),
      departsAt: departsAt.toUtc(),
    ),
  );

  @override
  Future<JourneyModel> complete(String id) => _change(
    id,
    (JourneyModel j) => j.copyWith(status: JourneyStatus.completed),
  );

  @override
  Future<JourneyModel> cancel(String id) => _change(
    id,
    (JourneyModel j) => j.copyWith(status: JourneyStatus.cancelled),
  );

  /// Applies [change] to a **planned** journey and stamps `updatedAt`.
  Future<JourneyModel> _change(
    String id,
    JourneyModel Function(JourneyModel) change,
  ) async {
    final (String key, List<JourneyModel> all) = await _load();
    final int i = all.indexWhere((JourneyModel j) => j.id == id);
    if (i < 0) throw const JourneyFailure(JourneyFailureCode.notFound);
    if (all[i].status != JourneyStatus.planned) {
      throw const JourneyFailure(JourneyFailureCode.notPlanned);
    }
    final JourneyModel changed = change(
      all[i],
    ).copyWith(updatedAt: _clock().toUtc());
    await _save(key, List<JourneyModel>.of(all)..[i] = changed);
    return changed;
  }

  /// The signed-in account's storage key and its journeys.
  Future<(String, List<JourneyModel>)> _load() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) throw const JourneyFailure(JourneyFailureCode.signedOut);
    final String key = keyFor(user.id);
    try {
      final String? raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return (key, <JourneyModel>[]);
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return (
        key,
        list
            .map(
              (dynamic j) => JourneyModel.fromJson(j as Map<String, dynamic>),
            )
            .toList(),
      );
    } on Object {
      throw const JourneyFailure(JourneyFailureCode.storage);
    }
  }

  Future<void> _save(String key, List<JourneyModel> all) async {
    try {
      await _storage.write(
        key: key,
        value: jsonEncode(all.map((JourneyModel j) => j.toJson()).toList()),
      );
    } on Object {
      throw const JourneyFailure(JourneyFailureCode.storage);
    }
    _changes.add(null);
  }

  /// Time-ordered and unguessable enough for one phone: the creation time in
  /// base 36, then 6 random hex digits.
  static String _newId(DateTime now) {
    final Random random = Random.secure();
    final String tail = List<String>.generate(
      3,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${now.microsecondsSinceEpoch.toRadixString(36)}$tail';
  }
}
