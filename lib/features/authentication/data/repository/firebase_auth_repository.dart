import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';

/// [AuthRepository] over Firebase Authentication, with the profile in
/// Firestore at `users/{uid}` (docs/firebase-architecture.md §3, §5.2).
///
/// - **Passwords never reach SafeRide's code beyond the call** — Firebase
///   Authentication holds them; Firestore holds name, phone and language.
/// - **The session is Firebase's**, kept on the phone across restarts.
/// - **One listener on the profile** while signed in, so the greeting and
///   Profile follow an edit made on another phone at no extra reads.
/// - A profile whose first write never landed is **rebuilt** from what the
///   Auth account knows (the name is copied to its display name at
///   registration for exactly that), never left as an account that cannot
///   open Home.
///
/// Also the app's [SessionReader]: other features learn the uid from it.
class FirebaseAuthRepository implements AuthRepository, SessionReader {
  FirebaseAuthRepository(this._auth, this._db, {this.accountData}) {
    // For the app's lifetime: the repository is a singleton.
    _auth.authStateChanges().listen(_follow);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// What else keeps data for an account, in the order to erase it. A
  /// function: they depend on this repository as the session.
  final List<AccountData> Function()? accountData;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileWatch;

  /// The signed-in account's profile as the listener last saw it.
  ({String uid, String fullName, String? phone})? _profile;

  /// A delete that hears nothing for this long counts as a lost connection.
  static const Duration _deleteWait = Duration(seconds: 30);

  /// The one form of an email the app sends.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String _tidy(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? _optional(String? value) {
    final String? v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<bool> hasSession() async {
    // The first event is the session Firebase restored on this phone.
    await _auth.authStateChanges().first;
    return _auth.currentUser != null;
  }

  @override
  Future<UserModel?> currentUser() => _guard(() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    return _model(user, await _readProfile(user));
  });

  @override
  Future<SessionUser?> signedInUser() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;
    final String name = _profile?.uid == user.uid
        ? _profile!.fullName
        : (user.displayName ?? '');
    return SessionUser(id: user.uid, fullName: name);
  }

  @override
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    required String languageCode,
    String? phone,
  }) => _guard(() async {
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(
          email: normalizeEmail(email),
          password: password,
        );
    final User user = credential.user!;
    final String name = _tidy(fullName);
    final String? number = _optional(phone);
    // A spare copy of the name: rebuilds the profile if its write is lost.
    await user.updateDisplayName(name);
    await settle(
      _profileDoc(user.uid).set(<String, Object?>{
        'fullName': name,
        'phone': number,
        'locale': languageCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _profile = (uid: user.uid, fullName: name, phone: number);
    _changes.add(null);
    return _model(user, _profile!);
  });

  @override
  Future<UserModel> login({required String email, required String password}) =>
      _guard(() async {
        final UserCredential credential = await _auth
            .signInWithEmailAndPassword(
              email: normalizeEmail(email),
              password: password,
            );
        final User user = credential.user!;
        return _model(user, await _readProfile(user));
      });

  @override
  Future<void> sendPasswordReset({
    required String email,
    required String languageCode,
  }) => _guard(() async {
    try {
      await _auth.setLanguageCode(languageCode);
    } on Object {
      // The email then comes in the project's default language — still sent.
    }
    await _auth.sendPasswordResetEmail(email: normalizeEmail(email));
  });

  @override
  Future<UserModel> updateProfile({required String fullName, String? phone}) =>
      _guard(() async {
        final User? user = _auth.currentUser;
        if (user == null) throw const AuthFailure(AuthFailureCode.storage);
        final String name = _tidy(fullName);
        final String? number = _optional(phone);
        await settle(
          _profileDoc(user.uid).set(<String, Object?>{
            'fullName': name,
            'phone': number,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
        _profile = (uid: user.uid, fullName: name, phone: number);
        _changes.add(null);
        return _model(user, _profile!);
      });

  @override
  Future<void> saveLanguage(String languageCode) => _guard(() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    await settle(
      _profileDoc(user.uid).set(<String, Object?>{
        'locale': languageCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  });

  @override
  Future<void> logout() => _guard(() async {
    // Off before the session ends: the rules refuse a signed-out listener.
    await _profileWatch?.cancel();
    _profileWatch = null;
    _profile = null;
    await _auth.signOut();
  });

  @override
  Future<void> deleteAccount({required String password}) => _guard(() async {
    final User? user = _auth.currentUser;
    final String? email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure(AuthFailureCode.storage);
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    final String uid = user.uid;
    for (final AccountData data in accountData?.call() ?? <AccountData>[]) {
      await data.erase(uid);
    }
    await _profileWatch?.cancel();
    _profileWatch = null;
    await _profileDoc(uid).delete().timeout(_deleteWait);
    _profile = null;
    await user.delete();
  });

  /// Follows the session: watches the signed-in account's profile, and tells
  /// listeners whenever who is signed in changes.
  void _follow(User? user) {
    unawaited(_profileWatch?.cancel());
    _profileWatch = null;
    if (_profile?.uid != user?.uid) _profile = null;
    if (user != null) {
      _profileWatch = _profileDoc(user.uid).snapshots().listen((
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) return;
        _profile = _read(user.uid, data);
        _changes.add(null);
      }, onError: (Object _) {});
    }
    _changes.add(null);
  }

  Future<({String uid, String fullName, String? phone})> _readProfile(
    User user,
  ) async {
    final ({String uid, String fullName, String? phone})? known = _profile;
    if (known != null && known.uid == user.uid) return known;
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _profileDoc(user.uid).get();
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      // Offline with nothing cached: what the Auth account knows, for now.
      // Not kept, and not written: the real profile may hold more.
      return (uid: user.uid, fullName: user.displayName ?? '', phone: null);
    }
    final Map<String, dynamic>? data = snapshot.data();
    if (data != null) return _profile = _read(user.uid, data);
    // Registration created the account but its profile never landed.
    final String name = _tidy(
      user.displayName ?? (user.email ?? '').split('@').first,
    );
    await settle(
      _profileDoc(user.uid).set(<String, Object?>{
        'fullName': name,
        'phone': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return _profile = (uid: user.uid, fullName: name, phone: null);
  }

  static ({String uid, String fullName, String? phone}) _read(
    String uid,
    Map<String, dynamic> data,
  ) => (
    uid: uid,
    fullName: (data['fullName'] as String?) ?? '',
    phone: data['phone'] as String?,
  );

  static UserModel _model(
    User user,
    ({String uid, String fullName, String? phone}) profile,
  ) => UserModel(
    fullName: profile.fullName,
    email: user.email ?? '',
    phone: profile.phone,
    createdAt: (user.metadata.creationTime ?? DateTime.now()).toUtc(),
  );

  /// Lets an [AuthFailure] through and turns everything Firebase throws into
  /// one, so no Firebase type leaves the repository.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure(AuthFailureCode.network);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(codeOf(e.code));
    } on FirebaseException catch (e) {
      throw AuthFailure(
        e.code == 'unavailable' || e.code == 'deadline-exceeded'
            ? AuthFailureCode.network
            : AuthFailureCode.storage,
      );
    } on Object {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  /// Firebase Authentication's error codes, as the app's.
  static AuthFailureCode codeOf(String code) => switch (code) {
    'email-already-in-use' => AuthFailureCode.emailTaken,
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => AuthFailureCode.invalidCredentials,
    'invalid-email' => AuthFailureCode.invalidEmail,
    'weak-password' => AuthFailureCode.weakPassword,
    'too-many-requests' => AuthFailureCode.tooManyRequests,
    'network-request-failed' => AuthFailureCode.network,
    'user-disabled' => AuthFailureCode.disabled,
    _ => AuthFailureCode.unknown,
  };
}
