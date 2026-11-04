import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/session/session_reader.dart';

/// The country the user says they are in now — what the emergency numbers
/// follow. Never guessed from the SIM, the language or the location: the
/// user chooses it. Shared by the Safety and Profile screens.
abstract interface class CountryRepository {
  /// This phone's copy: available at once, offline too.
  Country? current();

  /// Keeps [code] on this phone (done when this returns), then sends it to
  /// the account in the background.
  Future<void> choose(String code);

  /// Brings this phone and the signed-in account into agreement (after a
  /// sign-in, on a new phone, or when an offline change is still unsent).
  Future<void> reconcile();

  /// Fires when [current] changed.
  Stream<void> get changes;
}

/// [CountryRepository] over [AppPreferences] (this phone) and the profile's
/// `country` field (`users/{uid}`, the account).
///
/// **One rule settles a disagreement:** a choice made on this phone that the
/// account has not confirmed yet wins and is sent; otherwise the account's
/// value wins. So an offline change is never undone by an older copy, and a
/// new phone takes the account's country after sign-in. A phone with a
/// country the account lacks gives it to the account.
class ProfileCountryRepository implements CountryRepository {
  ProfileCountryRepository(this._prefs, this._db, this._session);

  final AppPreferences _prefs;
  final FirebaseFirestore _db;
  final SessionReader _session;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Country? current() => Countries.byCode(_prefs.country.code);

  @override
  Future<void> choose(String code) async {
    if (Countries.byCode(code) == null) {
      throw ArgumentError.value(code, 'code', 'not a supported country');
    }
    final String? uid = await _uid();
    await _prefs.setCountry(code, uid: uid, pending: true);
    _changes.add(null);
    if (uid != null) unawaited(_send(uid, code));
  }

  @override
  Future<void> reconcile() async {
    final String? uid = await _uid();
    if (uid == null) return;
    final ({String? code, String? uid, bool pending}) local = _prefs.country;
    final String? mine = local.code;
    if (mine != null && local.pending && (local.uid ?? uid) == uid) {
      return _send(uid, mine);
    }
    final String? remote;
    try {
      final Object? stored = (await _profile(uid).get()).data()?['country'];
      remote = stored is String ? stored : null;
    } on Object {
      return; // Offline with nothing cached: keep this phone's country.
    }
    if (Countries.byCode(remote) != null) {
      if (remote != mine || local.uid != uid) {
        await _prefs.setCountry(remote!, uid: uid, pending: false);
        if (remote != mine) _changes.add(null);
      }
    } else if (mine != null) {
      await _prefs.setCountry(mine, uid: uid, pending: true);
      await _send(uid, mine);
    }
  }

  /// Sends [code] to [uid]'s profile; marks it confirmed once the server has
  /// it (offline, when the connection returns). A refusal leaves it pending
  /// for the next [reconcile].
  Future<void> _send(String uid, String code) async {
    final Future<void> write = _profile(uid).set(<String, Object?>{
      'country': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      if (await settle(write)) {
        await _confirmed(uid, code);
      } else {
        unawaited(write.then((_) => _confirmed(uid, code), onError: (_) {}));
      }
    } on Object {
      // Stays pending.
    }
  }

  Future<void> _confirmed(String uid, String code) async {
    final ({String? code, String? uid, bool pending}) local = _prefs.country;
    if (local.code == code) {
      await _prefs.setCountry(code, uid: uid, pending: false);
    }
  }

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  Future<String?> _uid() async => (await _session.signedInUser())?.id;
}
