import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';

/// The potential-incident events, kept on the phone. The next batch reads
/// them for its safety check. `FileIncidentRepository` implements it.
abstract interface class IncidentRepository {
  /// [uid]'s events, oldest first.
  Future<List<PotentialIncident>> forUser(String uid);

  /// [uid]'s events for [journeyId], oldest first.
  Future<List<PotentialIncident>> forJourney(String uid, String journeyId);

  /// Adds [incident], or replaces the one with its id.
  Future<void> put(PotentialIncident incident);

  /// Forgets every event of [uid]: the account is being deleted.
  Future<void> eraseAccount(String uid);

  /// Fires after every [put].
  Stream<void> get changes;
}

/// [IncidentRepository] as one JSON file per account in the app's private
/// support directory (`incidents/<uid>.json`), replaced atomically; it
/// survives the app being closed. **Local only, on purpose:** events change
/// state often and matter only on this phone — no Firestore writes. At most
/// [keep] events per account, the oldest closed ones going first, and a
/// closed one for no longer than [retention].
class FileIncidentRepository implements IncidentRepository {
  FileIncidentRepository({
    Future<Directory> Function()? root,
    DateTime Function()? clock,
  }) : _root = root ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now;

  /// Events kept per account.
  static const int keep = 100;

  /// How long a closed event stays: long enough to look back on a journey,
  /// not a growing record of where someone stopped.
  static const Duration retention = Duration(days: 90);

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]+$');

  final Future<Directory> Function() _root;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _queue = Future<void>.value();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<PotentialIncident>> forUser(String uid) => _read(uid);

  @override
  Future<List<PotentialIncident>> forJourney(
    String uid,
    String journeyId,
  ) async => <PotentialIncident>[
    for (final PotentialIncident i in await _read(uid))
      if (i.journeyId == journeyId) i,
  ];

  @override
  Future<void> put(PotentialIncident incident) {
    final Future<void> done = _queue.then((_) async {
      final List<PotentialIncident> all = await _read(incident.uid);
      final int at = all.indexWhere(
        (PotentialIncident i) => i.id == incident.id,
      );
      if (at == -1) {
        all.add(incident);
      } else {
        all[at] = incident;
      }
      final DateTime oldest = _clock().toUtc().subtract(retention);
      all.removeWhere(
        (PotentialIncident i) => _closed(i) && i.updatedAt.isBefore(oldest),
      );
      while (all.length > keep) {
        // Only finished ones go: an open, asked or escalation-ready event
        // is never dropped to make room.
        final int closed = all.indexWhere(_closed);
        all.removeAt(closed == -1 ? 0 : closed);
      }
      final File file = await _file(incident.uid);
      await file.parent.create(recursive: true);
      final File aside = File('${file.path}.new');
      await aside.writeAsString(
        jsonEncode(<Object?>[for (final i in all) i.toJson()]),
        flush: true,
      );
      await aside.rename(file.path);
      _changes.add(null);
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  static bool _closed(PotentialIncident i) =>
      i.status == IncidentStatus.dismissed ||
      i.status == IncidentStatus.resolved ||
      i.status == IncidentStatus.superseded;

  @override
  Future<void> eraseAccount(String uid) {
    final Future<void> done = _queue.then((_) async {
      final File file = await _file(uid);
      if (await file.exists()) await file.delete();
      _changes.add(null);
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<List<PotentialIncident>> _read(String uid) async {
    final File file = await _file(uid);
    if (!await file.exists()) return <PotentialIncident>[];
    try {
      return <PotentialIncident>[
        for (final Object? e in jsonDecode(await file.readAsString()) as List)
          PotentialIncident.fromJson(e! as Map<String, dynamic>),
      ];
    } on Object {
      return <PotentialIncident>[]; // A damaged file is never trusted.
    }
  }

  Future<File> _file(String uid) async {
    if (!_id.hasMatch(uid)) throw ArgumentError.value(uid, 'uid');
    return File('${(await _root()).path}/incidents/$uid.json');
  }
}
