import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';

/// [TrustedContactsRepository] for the MVP: each account's contacts on
/// **this phone only**, in `flutter_secure_storage` (names and numbers are
/// personal), one JSON list per account under `contacts.<account id>`.
///
/// ⚠️ **Local only.** Nothing verifies a number or reaches a contact;
/// signing out keeps the list, as it keeps the account.
class LocalTrustedContactsRepository implements TrustedContactsRepository {
  LocalTrustedContactsRepository(
    this._storage,
    this._session, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final SessionReader _session;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// A short list of the people who matter, not an address book.
  static const int maxContacts = 20;

  static String keyFor(String accountId) => 'contacts.$accountId';

  /// The number's digits — "+966 50-123" and "+96650123" are one number.
  static String digitsOf(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<TrustedContactModel>> contacts() async {
    final List<TrustedContactModel> all = List<TrustedContactModel>.of(
      (await _load()).$2,
    );
    all.sort(
      (TrustedContactModel a, TrustedContactModel b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return all;
  }

  @override
  Future<TrustedContactModel?> contact(String id) async {
    for (final TrustedContactModel c in (await _load()).$2) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<TrustedContactModel> add({
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    final (String key, List<TrustedContactModel> all) = await _load();
    if (all.length >= maxContacts) {
      throw const ContactFailure(ContactFailureCode.full);
    }
    _checkUnique(all, phone);
    final DateTime now = _clock().toUtc();
    final TrustedContactModel contact = TrustedContactModel(
      id: _newId(now),
      fullName: _tidy(fullName),
      phone: phone.trim(),
      relationship: _optional(relationship),
      createdAt: now,
    );
    await _save(key, <TrustedContactModel>[...all, contact]);
    return contact;
  }

  @override
  Future<TrustedContactModel> update(
    String id, {
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    final (String key, List<TrustedContactModel> all) = await _load();
    final int i = all.indexWhere((TrustedContactModel c) => c.id == id);
    if (i < 0) throw const ContactFailure(ContactFailureCode.notFound);
    _checkUnique(all, phone, except: id);
    final TrustedContactModel changed = all[i].copyWith(
      fullName: _tidy(fullName),
      phone: phone.trim(),
      relationship: _optional(relationship),
    );
    await _save(key, List<TrustedContactModel>.of(all)..[i] = changed);
    return changed;
  }

  @override
  Future<void> delete(String id) async {
    final (String key, List<TrustedContactModel> all) = await _load();
    final List<TrustedContactModel> kept = all
        .where((TrustedContactModel c) => c.id != id)
        .toList();
    if (kept.length == all.length) {
      throw const ContactFailure(ContactFailureCode.notFound);
    }
    await _save(key, kept);
  }

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

  Future<(String, List<TrustedContactModel>)> _load() async {
    final SessionUser? user = await _session.signedInUser();
    if (user == null) throw const ContactFailure(ContactFailureCode.signedOut);
    final String key = keyFor(user.id);
    try {
      final String? raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return (key, <TrustedContactModel>[]);
      return (
        key,
        (jsonDecode(raw) as List<dynamic>)
            .map(
              (dynamic c) =>
                  TrustedContactModel.fromJson(c as Map<String, dynamic>),
            )
            .toList(),
      );
    } on Object {
      throw const ContactFailure(ContactFailureCode.storage);
    }
  }

  Future<void> _save(String key, List<TrustedContactModel> all) async {
    try {
      await _storage.write(
        key: key,
        value: jsonEncode(
          all.map((TrustedContactModel c) => c.toJson()).toList(),
        ),
      );
    } on Object {
      throw const ContactFailure(ContactFailureCode.storage);
    }
    _changes.add(null);
  }

  /// The creation time in base 36, then 6 random hex digits.
  static String _newId(DateTime now) {
    final Random random = Random.secure();
    final String tail = List<String>.generate(
      3,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${now.microsecondsSinceEpoch.toRadixString(36)}$tail';
  }
}
