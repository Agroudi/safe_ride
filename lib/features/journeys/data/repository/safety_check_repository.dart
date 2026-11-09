import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';

/// The safety checks, kept on the phone; `EscalationSync` reports the
/// escalation-ready ones. `FileSafetyCheckRepository` implements it.
abstract interface class SafetyCheckRepository {
  /// [uid]'s checks, oldest first.
  Future<List<SafetyCheck>> forUser(String uid);

  /// Adds [check], or replaces the one with its id.
  Future<void> put(SafetyCheck check);

  /// Forgets every check of [uid]: the account is being deleted.
  Future<void> eraseAccount(String uid);
}

/// [SafetyCheckRepository] as one JSON file per account in the app's
/// private support directory (`safety_checks/<uid>.json`), replaced
/// atomically, so a check survives the app being closed. At most [keep] per
/// account, finished ones going first, and a finished one for no longer than
/// [retention]. An unanswered one is never dropped by age.
class FileSafetyCheckRepository implements SafetyCheckRepository {
  FileSafetyCheckRepository({
    Future<Directory> Function()? root,
    DateTime Function()? clock,
  }) : _root = root ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  static const int keep = 50;

  /// How long a finished check stays.
  static const Duration retention = Duration(days: 90);

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]+$');

  final Future<Directory> Function() _root;
  final DateTime Function() _clock;
  Future<void> _queue = Future<void>.value();

  @override
  Future<List<SafetyCheck>> forUser(String uid) async {
    final File file = await _file(uid);
    if (!await file.exists()) return <SafetyCheck>[];
    try {
      return <SafetyCheck>[
        for (final Object? e in jsonDecode(await file.readAsString()) as List)
          SafetyCheck.fromJson(e! as Map<String, dynamic>),
      ];
    } on Object {
      return <SafetyCheck>[]; // A damaged file is never trusted.
    }
  }

  @override
  Future<void> put(SafetyCheck check) {
    final Future<void> done = _queue.then((_) async {
      final List<SafetyCheck> all = await forUser(check.uid);
      final int at = all.indexWhere((SafetyCheck c) => c.id == check.id);
      if (at == -1) {
        all.add(check);
      } else {
        all[at] = check;
      }
      final DateTime oldest = _clock().toUtc().subtract(retention);
      all.removeWhere(
        (SafetyCheck c) => _finished(c) && c.startedAt.isBefore(oldest),
      );
      while (all.length > keep) {
        final int finished = all.indexWhere(_finished);
        all.removeAt(finished == -1 ? 0 : finished);
      }
      final File file = await _file(check.uid);
      await file.parent.create(recursive: true);
      final File aside = File('${file.path}.new');
      await aside.writeAsString(
        jsonEncode(<Object?>[for (final c in all) c.toJson()]),
        flush: true,
      );
      await aside.rename(file.path);
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  static bool _finished(SafetyCheck c) => c.stage.isFinal;

  @override
  Future<void> eraseAccount(String uid) {
    final Future<void> done = _queue.then((_) async {
      final File file = await _file(uid);
      if (await file.exists()) await file.delete();
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<File> _file(String uid) async {
    if (!_id.hasMatch(uid)) throw ArgumentError.value(uid, 'uid');
    return File('${(await _root()).path}/safety_checks/$uid.json');
  }
}
