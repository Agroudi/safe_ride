import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/firebase/user_collection.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/data/repository/connection_link_check.dart';
import 'package:safe_ride/features/safety/data/repository/connection_repository.dart';

typedef _Doc = DocumentReference<Map<String, dynamic>>;

/// [ConnectionRepository] over Firestore, with no backend: `firestore.rules`
/// is what makes this safe, and every check here only gives a better message
/// than the refusal would (`docs/connections.md`).
///
/// **Transactions, not writes.** A write made offline waits in the phone's
/// queue and looks done; a transaction fails instead. So accepting, ending and
/// cancelling either reached the server or say they did not.
///
/// **They only write.** What needs checking is read from the server first, and
/// the rules decide regardless. Read inside a transaction and the SDK retries
/// it, and a failure thrown there can lose to the plugin's own: on a device
/// that showed a connection that had just been made as a lost one. And a
/// commit's answer can be lost after it landed, so [_commit] asks the server
/// before anything is called a failure.
class FirestoreConnectionRepository
    implements ConnectionRepository, AccountData {
  FirestoreConnectionRepository(
    this._db,
    this._session,
    this._links, {
    DateTime Function()? clock,
    String Function()? newToken,
  }) : _clock = clock ?? DateTime.now,
       _newToken = newToken ?? BearerToken.generate {
    _connections = UserCollection<ConnectionModel>(
      db: _db,
      path: FirestorePaths.connections,
      read: (String _, Map<String, dynamic> data) =>
          ConnectionModel.fromJson(data),
      watchFreshness: true,
    );
    _invites = UserCollection<ConnectionInviteModel>(
      db: _db,
      path: (_) => FirestorePaths.connectionInvites,
      read: (String id, Map<String, dynamic> data) =>
          ConnectionInviteModel.fromJson(<String, dynamic>{
            ...data,
            'token': id,
          }),
      query: _mine,
    );
    _connections.changes.listen(_changes.add);
    _invites.changes.listen(_changes.add);
  }

  final FirebaseFirestore _db;
  final SessionReader _session;
  final ConnectionLinkCheck _links;
  final DateTime Function() _clock;
  final String Function() _newToken;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late final UserCollection<ConnectionModel> _connections;
  late final UserCollection<ConnectionInviteModel> _invites;

  /// A few people who matter, as with saved contacts. Rules cannot count, so
  /// this is the app's limit, not a boundary.
  static const int maxConnections = 20;

  /// Invites waiting at once. Each one is a live key, so few are better.
  static const int maxPendingInvites = 5;

  static const Duration _wait = Duration(seconds: 10);

  /// Firestore allows 500 writes per batch.
  static const int _batchSize = 400;

  static Query<Map<String, dynamic>> _mine(
    Query<Map<String, dynamic>> all,
    String uid,
  ) => all.where('inviterUid', isEqualTo: uid);

  _Doc _invite(String token) => _db.doc(FirestorePaths.connectionInvite(token));

  _Doc _connection(String uid, String contactUid) =>
      _db.doc(FirestorePaths.connection(uid, contactUid));

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool get mayBeStale => _connections.fromCache;

  @override
  Future<List<ConnectionModel>> connections() => _guard(() async {
    final String uid = await _uid();
    return List<ConnectionModel>.of(await _connections.items(uid))..sort(
      (ConnectionModel a, ConnectionModel b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  });

  @override
  Future<List<ConnectionInviteModel>> invites() => _guard(() async {
    final String uid = await _uid();
    return <ConnectionInviteModel>[
      for (final ConnectionInviteModel i in await _invites.items(uid))
        if (i.status == ConnectionStatus.pending) i,
    ]..sort(
      (ConnectionInviteModel a, ConnectionInviteModel b) =>
          b.createdAt.compareTo(a.createdAt),
    );
  });

  @override
  Future<ConnectionInviteModel> createInvite() => _guard(() async {
    final String uid = await _uid();
    final DateTime now = _clock();
    final List<ConnectionInviteModel> mine = await _invites.items(uid);
    final int open = mine
        .where(
          (ConnectionInviteModel i) =>
              i.statusAt(now) == ConnectionStatus.pending,
        )
        .length;
    if (open >= maxPendingInvites || await _connected(uid) >= maxConnections) {
      throw const ConnectionFailure(ConnectionFailureCode.tooMany);
    }
    if (!await _links.pageReady()) {
      throw const ConnectionFailure(ConnectionFailureCode.unavailable);
    }

    final String token = _newToken();
    final DateTime expiresAt = now.add(ConnectionInviteModel.lifetime).toUtc();
    final String name = await _profileName(uid);
    final _Doc invite = _invite(token);
    await _commit((Transaction tx) {
      tx.set(invite, <String, Object>{
        'inviterUid': uid,
        'inviterName': name,
        'status': ConnectionStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    }, landed: () async => (await _fromServer(invite)).exists);
    await _tidy(mine);
    return ConnectionInviteModel(
      token: token,
      inviterUid: uid,
      inviterName: name,
      status: ConnectionStatus.pending,
      createdAt: now.toUtc(),
      expiresAt: expiresAt,
    );
  });

  Future<int> _connected(String uid) async => (await _connections.items(
    uid,
  )).where((ConnectionModel c) => c.isActive).length;

  /// Invites that were used have no more to do: names and ids do not stay
  /// around for nothing. It can wait for the next time, so it never fails.
  Future<void> _tidy(List<ConnectionInviteModel> mine) async {
    final WriteBatch batch = _db.batch();
    final List<ConnectionInviteModel> used = <ConnectionInviteModel>[
      for (final ConnectionInviteModel i in mine)
        if (i.status == ConnectionStatus.accepted) i,
    ];
    if (used.isEmpty) return;
    for (final ConnectionInviteModel i in used) {
      batch.delete(_invite(i.token));
    }
    await settle(batch.commit());
  }

  Future<String> _profileName(String uid) async {
    final Object? name = (await _fromServer(
      _db.doc(FirestorePaths.user(uid)),
    )).data()?['fullName'];
    if (name is! String) {
      throw const ConnectionFailure(ConnectionFailureCode.profileMissing);
    }
    return name;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fromServer(_Doc doc) =>
      doc.get(const GetOptions(source: Source.server)).timeout(_wait);

  /// One atomic write that is never queued. A failure is believed only once
  /// the server, asked through [landed], says it did not happen.
  Future<void> _commit(
    void Function(Transaction tx) write, {
    required Future<bool> Function() landed,
  }) async {
    try {
      await _db.runTransaction<void>(
        (Transaction tx) async => write(tx),
        timeout: _wait,
        maxAttempts: 1,
      );
    } on FirebaseException {
      if (!await _didLand(landed)) rethrow;
    }
  }

  Future<bool> _didLand(Future<bool> Function() landed) async {
    try {
      return await landed();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> cancelInvite(String token) => _guard(() async {
    await _uid();
    final _Doc invite = _invite(token);
    await _commit(
      (Transaction tx) => tx.delete(invite),
      landed: () async {
        try {
          return !(await _fromServer(invite)).exists;
        } on FirebaseException catch (e) {
          // The rules answer for a missing invite as for one that is closed.
          return e.code == 'permission-denied';
        }
      },
    );
  });

  /// Refuses what cannot be accepted, so both the preview and the acceptance
  /// tell the person why. The rules decide regardless.
  void _check(ConnectionInviteModel invite, String uid) {
    if (invite.inviterUid == uid) {
      throw const ConnectionFailure(ConnectionFailureCode.ownInvite);
    }
    if (invite.status == ConnectionStatus.accepted &&
        invite.acceptedBy == uid) {
      throw const ConnectionFailure(ConnectionFailureCode.alreadyConnected);
    }
    if (invite.statusAt(_clock()) != ConnectionStatus.pending) {
      throw const ConnectionFailure(ConnectionFailureCode.noLongerValid);
    }
  }

  ConnectionInviteModel _read(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      throw const ConnectionFailure(ConnectionFailureCode.noLongerValid);
    }
    try {
      return ConnectionInviteModel.fromJson(<String, dynamic>{
        ...data,
        'token': doc.id,
      });
    } on Object {
      throw const ConnectionFailure(ConnectionFailureCode.noLongerValid);
    }
  }

  /// The invite, if [uid] may still answer it.
  Future<ConnectionInviteModel> _openInvite(String token, String uid) async {
    if (!BearerToken.isValid(token)) {
      throw const ConnectionFailure(ConnectionFailureCode.invalid);
    }
    final ConnectionInviteModel invite = _read(
      await _fromServer(_invite(token)),
    );
    _check(invite, uid);
    final DocumentSnapshot<Map<String, dynamic>> mine = await _fromServer(
      _connection(uid, invite.inviterUid),
    );
    if (mine.data()?['status'] == ConnectionStatus.accepted.name) {
      throw const ConnectionFailure(ConnectionFailureCode.alreadyConnected);
    }
    return invite;
  }

  @override
  Future<ConnectionInviteModel> preview(String token) => _guard(
    () async => _openInvite(token, await _uid()),
    refused: ConnectionFailureCode.noLongerValid,
  );

  @override
  Future<ConnectionModel> accept(String token) => _guard(() async {
    final String uid = await _uid();
    final ConnectionInviteModel invite = await _openInvite(token, uid);
    if (await _connected(uid) >= maxConnections) {
      throw const ConnectionFailure(ConnectionFailureCode.tooMany);
    }
    final String myName = await _profileName(uid);
    final Timestamp createdAt = Timestamp.fromDate(invite.createdAt);

    Map<String, Object> side(String owner, String contact, String name) =>
        <String, Object>{
          'ownerUid': owner,
          'contactUid': contact,
          'contactName': name,
          'status': ConnectionStatus.accepted.name,
          'inviteId': token,
          'createdAt': createdAt,
          'acceptedAt': FieldValue.serverTimestamp(),
          'permissions': const <String, bool>{'safetyAlerts': false},
        };

    // If someone else got there first, the rules refuse this whole write.
    await _commit(
      (Transaction tx) => tx
        ..update(_invite(token), <String, Object>{
          'status': ConnectionStatus.accepted.name,
          'acceptedBy': uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        })
        ..set(
          _connection(uid, invite.inviterUid),
          side(uid, invite.inviterUid, invite.inviterName),
        )
        ..set(
          _connection(invite.inviterUid, uid),
          side(invite.inviterUid, uid, myName),
        ),
      landed: () async =>
          (await _fromServer(_invite(token))).data()?['acceptedBy'] == uid,
    );
    return ConnectionModel(
      ownerUid: uid,
      contactUid: invite.inviterUid,
      contactName: invite.inviterName,
      status: ConnectionStatus.accepted,
      inviteId: token,
      createdAt: invite.createdAt,
      acceptedAt: _clock().toUtc(),
    );
  }, refused: ConnectionFailureCode.noLongerValid);

  Map<String, Object> _ended(String uid) => <String, Object>{
    'status': ConnectionStatus.revoked.name,
    'revokedAt': FieldValue.serverTimestamp(),
    'revokedBy': uid,
  };

  @override
  Future<void> revoke(String contactUid) => _guard(() async {
    final String uid = await _uid();
    final _Doc mine = _connection(uid, contactUid);
    final _Doc theirs = _connection(contactUid, uid);
    // Ended already, from the other phone.
    if ((await _fromServer(mine)).data()?['status'] !=
        ConnectionStatus.accepted.name) {
      return;
    }
    Future<bool> ended() async =>
        (await _fromServer(mine)).data()?['status'] ==
        ConnectionStatus.revoked.name;

    try {
      await _commit((Transaction tx) {
        tx
          ..update(mine, _ended(uid))
          ..update(theirs, _ended(uid));
      }, landed: ended);
    } on FirebaseException catch (e) {
      if (!_theirSideGone(e)) rethrow;
      await _commit(
        (Transaction tx) => tx.update(mine, _ended(uid)),
        landed: ended,
      );
    }
  });

  /// Their record cannot be written: their account was deleted outside the
  /// app, or they ended it in the same moment. Neither keeps this side open.
  static bool _theirSideGone(FirebaseException e) =>
      e.code == 'permission-denied' || e.code == 'not-found';

  @override
  Future<void> rename(String contactUid, String? nickname) => _guard(() async {
    final String uid = await _uid();
    final String word = (nickname ?? '').trim();
    // Only ever this account's own view of them, so it may wait for a signal.
    await settle(
      _connection(uid, contactUid).update(<String, Object>{
        'nickname': word.isEmpty ? FieldValue.delete() : word,
      }),
    );
  });

  @override
  Future<void> clear(String contactUid) => _guard(() async {
    final String uid = await _uid();
    await settle(_connection(uid, contactUid).delete());
  });

  /// What deleting the account takes with it: the other people are told it is
  /// over, and no invite of this account can be accepted afterwards. Reads go
  /// to the server, as in `FirestoreAccountData`.
  @override
  Future<void> erase(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> mine = await _db
        .collection(FirestorePaths.connections(uid))
        .get(const GetOptions(source: Source.server))
        .timeout(_wait);
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in mine.docs) {
      await _leave(uid, d).timeout(_wait);
    }
    final QuerySnapshot<Map<String, dynamic>> invites = await _mine(
      _db.collection(FirestorePaths.connectionInvites),
      uid,
    ).get(const GetOptions(source: Source.server)).timeout(_wait);
    for (int from = 0; from < invites.docs.length; from += _batchSize) {
      final WriteBatch batch = _db.batch();
      final int to = (from + _batchSize).clamp(0, invites.docs.length);
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d
          in invites.docs.sublist(from, to)) {
        batch.delete(d.reference);
      }
      await batch.commit().timeout(_wait);
    }
  }

  Future<void> _leave(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> mine,
  ) async {
    if (mine.data()['status'] == ConnectionStatus.accepted.name) {
      try {
        final WriteBatch both = _db.batch()
          ..update(_connection(mine.id, uid), _ended(uid))
          ..delete(mine.reference);
        await both.commit();
        return;
      } on FirebaseException catch (e) {
        if (!_theirSideGone(e)) rethrow;
      }
    }
    await mine.reference.delete();
  }

  Future<String> _uid() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) {
      throw const ConnectionFailure(ConnectionFailureCode.signedOut);
    }
    return user.id;
  }

  /// [refused] is what the rules saying no means to this call.
  Future<T> _guard<T>(
    Future<T> Function() step, {
    ConnectionFailureCode refused = ConnectionFailureCode.unavailable,
  }) async {
    try {
      return await step();
    } on FirebaseException catch (e) {
      // Only the rules saying no is a refusal. Offline, a transaction ends in
      // more than one code, and none of them says anything about the invite.
      throw ConnectionFailure(
        e.code == 'permission-denied' || e.code == 'not-found'
            ? refused
            : ConnectionFailureCode.offline,
      );
    } on TimeoutException {
      throw const ConnectionFailure(ConnectionFailureCode.offline);
    }
  }
}
