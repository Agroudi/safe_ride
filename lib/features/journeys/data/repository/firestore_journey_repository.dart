import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/firebase/user_collection.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';

/// [JourneyRepository] over Firestore: the signed-in account's journeys at
/// `users/{uid}/journeys` (docs/firebase-architecture.md §5.3).
///
/// - **One live query** — the newest [maxJourneys] — shared by Home, My
///   Journeys and the planning screens; a reload reads it, not Firestore.
/// - **Offline:** reads come from the phone's copy; a change is saved there
///   at once and sent when the connection returns (`settle`).
/// - **The rules are the boundary** (`firestore.rules`): only the owner
///   reaches these documents; planned → active only together with a complete
///   pre-journey checklist; only a planned journey is edited; active →
///   completed; a closed one never reopens. The checks here mirror them for
///   a clear error.
/// - Journeys are records: nothing here deletes one.
class FirestoreJourneyRepository implements JourneyRepository {
  FirestoreJourneyRepository(
    this._db,
    this._session, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _journeys = UserCollection<JourneyModel>(
      db: _db,
      path: FirestorePaths.journeys,
      read: _model,
      query: (Query<Map<String, dynamic>> q, String _) =>
          q.orderBy('createdAt', descending: true).limit(maxJourneys),
    );
  }

  final FirebaseFirestore _db;
  final SessionReader _session;
  final DateTime Function() _clock;
  late final UserCollection<JourneyModel> _journeys;

  /// How many of the newest journeys the app loads.
  static const int maxJourneys = 200;

  @override
  Stream<void> get changes => _journeys.changes;

  @override
  Future<List<JourneyModel>> journeys() => _guard(() async {
    // Newest first, with a just-planned journey first even while its
    // server time is pending.
    return List<JourneyModel>.of(await _journeys.items(await _uid()))..sort(
      (JourneyModel a, JourneyModel b) => b.createdAt.compareTo(a.createdAt),
    );
  });

  @override
  Future<JourneyModel?> journey(String id) => _guard(() => _find(id));

  @override
  Future<JourneyModel> plan({
    required String origin,
    required String destination,
    required DateTime departsAt,
    JourneyPlace? originPlace,
    JourneyPlace? destinationPlace,
    double? plannedDistanceMeters,
    double? plannedDurationSeconds,
  }) => _guard(() async {
    final DocumentReference<Map<String, dynamic>> doc = _journeys
        .ref(await _uid())
        .doc();
    final DateTime now = _clock().toUtc();
    final JourneyModel journey = JourneyModel(
      id: doc.id,
      origin: origin.trim(),
      destination: destination.trim(),
      status: JourneyStatus.planned,
      departsAt: departsAt.toUtc(),
      createdAt: now,
      updatedAt: now,
      originPlace: originPlace,
      destinationPlace: destinationPlace,
      plannedDistanceMeters: plannedDistanceMeters,
      plannedDurationSeconds: plannedDurationSeconds,
    );
    await settle(
      doc.set(<String, Object?>{
        'origin': journey.origin,
        'destination': journey.destination,
        'departsAt': Timestamp.fromDate(journey.departsAt),
        'status': JourneyStatus.planned.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // A journey with no pins has none of these fields at all.
        if (originPlace != null) 'originPlace': originPlace.toJson(),
        if (destinationPlace != null)
          'destinationPlace': destinationPlace.toJson(),
        'plannedDistanceMeters': ?plannedDistanceMeters,
        'plannedDurationSeconds': ?plannedDurationSeconds,
      }),
    );
    return journey;
  });

  @override
  Future<JourneyModel> update(
    String id, {
    required String origin,
    required String destination,
    required DateTime departsAt,
    JourneyPlace? originPlace,
    JourneyPlace? destinationPlace,
    double? plannedDistanceMeters,
    double? plannedDurationSeconds,
  }) => _change(
    id,
    from: const <JourneyStatus>{JourneyStatus.planned},
    (JourneyModel j) => j.copyWith(
      origin: origin.trim(),
      destination: destination.trim(),
      departsAt: departsAt.toUtc(),
      originPlace: originPlace,
      destinationPlace: destinationPlace,
      plannedDistanceMeters: plannedDistanceMeters,
      plannedDurationSeconds: plannedDurationSeconds,
    ),
    // A place typed over its pin loses the pin, and the old estimate with it.
    fields: <String, Object?>{
      'originPlace': originPlace?.toJson() ?? FieldValue.delete(),
      'destinationPlace': destinationPlace?.toJson() ?? FieldValue.delete(),
      'plannedDistanceMeters': plannedDistanceMeters ?? FieldValue.delete(),
      'plannedDurationSeconds': plannedDurationSeconds ?? FieldValue.delete(),
    },
  );

  @override
  Future<({JourneyModel journey, bool synced})> start(
    String id, {
    required int checklistVersion,
    required Set<String> confirmed,
  }) => _guard(() async {
    if (!JourneyChecklist.isComplete(checklistVersion, confirmed)) {
      throw const JourneyFailure(JourneyFailureCode.checklistIncomplete);
    }
    final JourneyModel current = await _current(id, const <JourneyStatus>{
      JourneyStatus.planned,
    });
    final String uid = await _uid();
    final DateTime now = _clock().toUtc();
    // One atomic write: the record of what was confirmed, and the start it
    // allows. The rules accept neither alone, and a second start finds the
    // record already there.
    final WriteBatch batch = _db.batch()
      ..set(
        _db.doc(FirestorePaths.journeyChecklist(uid, id)),
        <String, Object?>{
          'journeyId': id,
          'uid': uid,
          'version': checklistVersion,
          'items': JourneyChecklist.itemsOf(checklistVersion),
          'complete': true,
          'completedAt': FieldValue.serverTimestamp(),
        },
      )
      ..update(_journeys.ref(uid).doc(id), <String, Object?>{
        'status': JourneyStatus.active.name,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    final bool synced = await settle(batch.commit());
    return (
      journey: current.copyWith(
        status: JourneyStatus.active,
        startedAt: now,
        updatedAt: now,
      ),
      synced: synced,
    );
  });

  @override
  Future<JourneyModel> complete(String id) => _change(
    id,
    from: const <JourneyStatus>{JourneyStatus.active},
    (JourneyModel j) => j.copyWith(status: JourneyStatus.completed),
  );

  @override
  Future<JourneyModel> cancel(String id) => _change(
    id,
    from: const <JourneyStatus>{JourneyStatus.planned, JourneyStatus.active},
    (JourneyModel j) => j.copyWith(status: JourneyStatus.cancelled),
  );

  /// Applies [change] to a journey whose status is one of [from], and stamps
  /// `updatedAt`.
  Future<JourneyModel> _change(
    String id,
    JourneyModel Function(JourneyModel) change, {
    required Set<JourneyStatus> from,
    Map<String, Object?> fields = const <String, Object?>{},
  }) => _guard(() async {
    final JourneyModel changed = change(
      await _current(id, from),
    ).copyWith(updatedAt: _clock().toUtc());
    await settle(
      _journeys.ref(await _uid()).doc(id).update(<String, Object?>{
        'origin': changed.origin,
        'destination': changed.destination,
        'departsAt': Timestamp.fromDate(changed.departsAt),
        'status': changed.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        ...fields,
      }),
    );
    return changed;
  });

  /// The journey, if its status is one of [allowed]; otherwise the failure
  /// that says why not.
  Future<JourneyModel> _current(String id, Set<JourneyStatus> allowed) async {
    final JourneyModel? current = await _find(id);
    if (current == null) {
      throw const JourneyFailure(JourneyFailureCode.notFound);
    }
    if (!allowed.contains(current.status)) {
      throw JourneyFailure(switch (current.status) {
        JourneyStatus.planned => JourneyFailureCode.notStarted,
        JourneyStatus.active => JourneyFailureCode.alreadyStarted,
        JourneyStatus.completed ||
        JourneyStatus.cancelled => JourneyFailureCode.notPlanned,
      });
    }
    return current;
  }

  /// From the live query, else (older than it reaches) the document itself.
  Future<JourneyModel?> _find(String id) async {
    final String uid = await _uid();
    for (final JourneyModel j in await _journeys.items(uid)) {
      if (j.id == id) return j;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await _journeys
        .ref(uid)
        .doc(id)
        .get();
    final Map<String, dynamic>? data = doc.data();
    return data == null ? null : _model(doc.id, data);
  }

  Future<String> _uid() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) throw const JourneyFailure(JourneyFailureCode.signedOut);
    return user.id;
  }

  static JourneyModel _model(String id, Map<String, dynamic> data) =>
      JourneyModel.fromJson(<String, dynamic>{...data, 'id': id});

  /// Lets a [JourneyFailure] through and turns everything else into one.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on JourneyFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw JourneyFailure(switch (e.code) {
        'unavailable' || 'deadline-exceeded' => JourneyFailureCode.network,
        'not-found' => JourneyFailureCode.notFound,
        _ => JourneyFailureCode.storage,
      });
    } on Object {
      throw const JourneyFailure(JourneyFailureCode.storage);
    }
  }
}
