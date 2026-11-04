import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/features/journeys/data/models/escalation.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_repository.dart';

/// [EscalationRepository] over Firestore. The request is one batch — the
/// check and its incident, or neither — that goes into Firestore's queue, so
/// offline it waits on the phone and survives a restart. No location goes
/// with it. The backend's trigger takes it from there
/// (`functions/src/escalation.ts`).
class FirestoreEscalationRepository implements EscalationRepository {
  const FirestoreEscalationRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _check(String uid, String id) =>
      _db.collection(FirestorePaths.safetyChecks(uid)).doc(id);

  @override
  Future<void> submit(SafetyCheck check, PotentialIncident incident) {
    final WriteBatch batch = _db.batch()
      ..set(
        _db.collection(FirestorePaths.incidents(check.uid)).doc(incident.id),
        <String, Object?>{
          'journeyId': incident.journeyId,
          'safetyCheckId': check.id,
          'type': incident.type.name,
          'confidence': incident.confidence.name,
          'detectedAt': Timestamp.fromDate(incident.detectedAt),
          'createdAt': FieldValue.serverTimestamp(),
        },
      )
      ..set(_check(check.uid, check.id), <String, Object?>{
        'uid': check.uid,
        'journeyId': check.journeyId,
        'incidentId': check.incidentId,
        'status': check.status.name,
        'startedAt': Timestamp.fromDate(check.startedAt),
        'deadline': Timestamp.fromDate(check.deadline),
        'timedOutAt': Timestamp.fromDate(check.deadline),
        'escalationReadyAt': Timestamp.fromDate(check.escalationReadyAt!),
        'syncedAt': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }

  @override
  Future<bool> received(String uid, String checkId) async => (await _check(
    uid,
    checkId,
  ).get(const GetOptions(source: Source.server))).exists;

  @override
  Stream<Escalation?> watch(String uid, String checkId) => _db
      .collection(FirestorePaths.escalations(uid))
      .doc(checkId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> d) {
        final Map<String, dynamic>? data = d.data();
        return data == null ? null : Escalation.fromJson(data);
      });
}
