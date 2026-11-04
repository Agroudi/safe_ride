import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/user_collection.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/received_alert.dart';
import 'package:safe_ride/features/safety/data/repository/received_alerts_repository.dart';

/// [ReceivedAlertsRepository] over `users/{uid}/receivedAlerts`: the newest
/// 50, on one live query.
class FirestoreReceivedAlertsRepository implements ReceivedAlertsRepository {
  FirestoreReceivedAlertsRepository(FirebaseFirestore db, this._session) {
    _alerts = UserCollection<ReceivedAlert>(
      db: db,
      path: FirestorePaths.receivedAlerts,
      read: (String id, Map<String, dynamic> data) =>
          ReceivedAlert.fromJson(<String, dynamic>{...data, 'id': id}),
      query: (Query<Map<String, dynamic>> q) =>
          q.orderBy('createdAt', descending: true).limit(50),
    );
  }

  final SessionReader _session;
  late final UserCollection<ReceivedAlert> _alerts;

  @override
  Stream<void> get changes => _alerts.changes;

  @override
  Future<List<ReceivedAlert>> alerts() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) throw const ContactFailure(ContactFailureCode.signedOut);
    try {
      return await _alerts.items(user.id);
    } on FirebaseException {
      throw const ContactFailure(ContactFailureCode.storage);
    }
  }
}
