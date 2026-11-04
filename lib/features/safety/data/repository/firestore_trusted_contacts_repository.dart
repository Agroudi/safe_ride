import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_ride/core/firebase/firestore_paths.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';
import 'package:safe_ride/core/firebase/user_collection.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';

/// [TrustedContactsRepository] over Firestore: the signed-in account's
/// contacts at `users/{uid}/contacts` (docs/firebase-architecture.md §5.4).
///
/// - **One live query** on the whole list (at most [maxContacts]), sorted by
///   name on the phone — no index, and a reload reads nothing.
/// - **Offline:** reads come from the phone's copy; a change is saved there
///   at once and sent when the connection returns (`settle`).
/// - The cap and the one-number-once check are the app's rules, checked
///   here; who may read or write is the security rules' (`firestore.rules`).
/// - Nothing verifies a number.
class FirestoreTrustedContactsRepository implements TrustedContactsRepository {
  FirestoreTrustedContactsRepository(
    this._db,
    this._session, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _contacts = UserCollection<TrustedContactModel>(
      db: _db,
      path: FirestorePaths.contacts,
      read: (String id, Map<String, dynamic> data) =>
          TrustedContactModel.fromJson(<String, dynamic>{...data, 'id': id}),
    );
  }

  final FirebaseFirestore _db;
  final SessionReader _session;
  final DateTime Function() _clock;
  late final UserCollection<TrustedContactModel> _contacts;

  /// A short list of the people who matter, not an address book.
  static const int maxContacts = 20;

  /// The number's digits — "+966 50-123" and "+96650123" are one number.
  static String digitsOf(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  @override
  Stream<void> get changes => _contacts.changes;

  @override
  Future<List<TrustedContactModel>> contacts() => _guard(() async {
    return List<TrustedContactModel>.of(await _all())..sort(
      (TrustedContactModel a, TrustedContactModel b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  });

  @override
  Future<TrustedContactModel?> contact(String id) => _guard(() async {
    for (final TrustedContactModel c in await _all()) {
      if (c.id == id) return c;
    }
    return null;
  });

  @override
  Future<TrustedContactModel> add({
    required String fullName,
    required String phone,
    String? relationship,
  }) => _guard(() async {
    final List<TrustedContactModel> all = await _all();
    if (all.length >= maxContacts) {
      throw const ContactFailure(ContactFailureCode.full);
    }
    _checkUnique(all, phone);
    final DocumentReference<Map<String, dynamic>> doc = _contacts
        .ref(await _uid())
        .doc();
    final TrustedContactModel contact = TrustedContactModel(
      id: doc.id,
      fullName: _tidy(fullName),
      phone: phone.trim(),
      relationship: _optional(relationship),
      createdAt: _clock().toUtc(),
    );
    await settle(
      doc.set(<String, Object?>{
        ..._fields(contact),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    return contact;
  });

  @override
  Future<TrustedContactModel> update(
    String id, {
    required String fullName,
    required String phone,
    String? relationship,
  }) => _guard(() async {
    final List<TrustedContactModel> all = await _all();
    final int i = all.indexWhere((TrustedContactModel c) => c.id == id);
    if (i < 0) throw const ContactFailure(ContactFailureCode.notFound);
    _checkUnique(all, phone, except: id);
    final TrustedContactModel changed = all[i].copyWith(
      fullName: _tidy(fullName),
      phone: phone.trim(),
      relationship: _optional(relationship),
    );
    await settle(_contacts.ref(await _uid()).doc(id).update(_fields(changed)));
    return changed;
  });

  @override
  Future<void> delete(String id) => _guard(() async {
    if (!(await _all()).any((TrustedContactModel c) => c.id == id)) {
      throw const ContactFailure(ContactFailureCode.notFound);
    }
    await settle(_contacts.ref(await _uid()).doc(id).delete());
  });

  Future<List<TrustedContactModel>> _all() async =>
      _contacts.items(await _uid());

  /// What a save writes; `createdAt` is the server's, on creation only.
  static Map<String, Object?> _fields(TrustedContactModel c) =>
      <String, Object?>{
        'fullName': c.fullName,
        'phone': c.phone,
        'phoneDigits': digitsOf(c.phone),
        'relationship': c.relationship,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static void _checkUnique(
    List<TrustedContactModel> all,
    String phone, {
    String? except,
  }) {
    final String digits = digitsOf(phone);
    if (all.any(
      (TrustedContactModel c) => c.id != except && digitsOf(c.phone) == digits,
    )) {
      throw const ContactFailure(ContactFailureCode.duplicatePhone);
    }
  }

  static String _tidy(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? _optional(String? value) {
    final String? v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  Future<String> _uid() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) throw const ContactFailure(ContactFailureCode.signedOut);
    return user.id;
  }

  /// Lets a [ContactFailure] through and turns everything else into one.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ContactFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw ContactFailure(switch (e.code) {
        'unavailable' || 'deadline-exceeded' => ContactFailureCode.network,
        'not-found' => ContactFailureCode.notFound,
        _ => ContactFailureCode.storage,
      });
    } on Object {
      throw const ContactFailure(ContactFailureCode.storage);
    }
  }
}
