import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/repository/connection_link_check.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_connection_repository.dart';

/// Someone signed in, or nobody when [id] is null.
class FakeConnectionSession implements SessionReader {
  FakeConnectionSession(this.id);

  String? id;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async {
    final String? uid = id;
    return uid == null ? null : SessionUser(id: uid, fullName: uid);
  }
}

/// Whether the invite page is there, decided by the test: no request is made.
class FakeConnectionLinks implements ConnectionLinkCheck {
  bool ready = true;
  bool offline = false;

  @override
  Future<bool> pageReady() async {
    if (offline) throw const ConnectionFailure(ConnectionFailureCode.offline);
    return ready;
  }
}

/// Firestore whose transactions fail with [transactionError] while it is set,
/// [failuresLeft] times when that is given. With [answerLost] the write lands
/// first, as when a commit reaches the server and its reply never comes back.
class FailingFirestore extends FakeFirebaseFirestore {
  String? transactionError;
  int? failuresLeft;
  bool answerLost = false;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (answerLost) {
      await super.runTransaction(transactionHandler);
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unknown');
    }
    final String? code = transactionError;
    if (code != null) {
      final int? left = failuresLeft;
      if (left != null) {
        failuresLeft = left - 1;
        if (left == 1) transactionError = null;
      }
      throw FirebaseException(plugin: 'cloud_firestore', code: code);
    }
    return super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

/// A connection repository for [uid] over [db].
FirestoreConnectionRepository connectionsFor(
  FirebaseFirestore db,
  String? uid, {
  FakeConnectionLinks? links,
  DateTime Function()? clock,
  String Function()? newToken,
}) => FirestoreConnectionRepository(
  db,
  FakeConnectionSession(uid),
  links ?? FakeConnectionLinks(),
  clock: clock,
  newToken: newToken,
);
