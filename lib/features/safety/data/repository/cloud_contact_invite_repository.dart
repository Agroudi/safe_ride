import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/user_collection.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/invite_failure.dart';
import 'package:safe_ride/features/safety/data/repository/contact_invite_repository.dart';

/// [ContactInviteRepository] over the backend's callable functions; the
/// links are read from `users/{uid}/contactLinks`, on one live query.
class CloudContactInviteRepository implements ContactInviteRepository {
  CloudContactInviteRepository(
    this._functions,
    FirebaseFirestore db,
    this._session,
  ) {
    _links = UserCollection<MapEntry<String, String>>(
      db: db,
      path: FirestorePaths.contactLinks,
      read: (String id, Map<String, dynamic> data) =>
          MapEntry<String, String>(id, data['phoneDigits'] as String),
    );
  }

  final FirebaseFunctions _functions;
  final SessionReader _session;
  late final UserCollection<MapEntry<String, String>> _links;

  @override
  Stream<void> get changes => _links.changes;

  @override
  Future<ContactInvite> create(String contactId) async {
    final Map<String, dynamic> result = await _call(
      'createContactInvite',
      <String, Object?>{'contactId': contactId},
    );
    return ContactInvite(
      code: result['code'] as String,
      expiresAt: DateTime.parse(result['expiresAt'] as String),
    );
  }

  @override
  Future<String> accept(String code) async {
    final Map<String, dynamic> result = await _call(
      'acceptContactInvite',
      <String, Object?>{'code': code},
    );
    return result['ownerName'] as String;
  }

  @override
  Future<Map<String, String>> links() async {
    final String? uid = (await _session.signedInUser())?.id;
    if (uid == null) return const <String, String>{};
    try {
      return Map<String, String>.fromEntries(await _links.items(uid));
    } on FirebaseException {
      return const <String, String>{};
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final HttpsCallableResult<Object?> result = await _functions
          .httpsCallable(name)
          .call<Object?>(data);
      return Map<String, dynamic>.from(result.data! as Map<Object?, Object?>);
    } on FirebaseFunctionsException catch (e) {
      throw InviteFailure(failureOf(e.code));
    }
  }

  /// The backend's codes (`functions/src/requests.ts`). `not-found` is a
  /// function that is not deployed, not a wrong code.
  static InviteFailureCode failureOf(String code) => switch (code) {
    'invalid-argument' => InviteFailureCode.invalidCode,
    'failed-precondition' => InviteFailureCode.noLongerValid,
    'permission-denied' => InviteFailureCode.ownInvite,
    'unavailable' || 'deadline-exceeded' => InviteFailureCode.network,
    _ => InviteFailureCode.unavailable,
  };
}
