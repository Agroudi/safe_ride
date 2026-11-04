import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/track_session.dart';
import 'package:safe_ride/features/journeys/data/repository/track_store.dart';

/// [TrackStore] as files in the app's private support directory
/// (`tracks/<uid>/<journeyId>.points` and `.session`), which no other app
/// can read.
///
/// - Points are **appended** one JSON line each and flushed, so the order is
///   the recorded order and a point survives the app being killed right
///   after it. A line cut short by a crash is skipped on reading.
/// - The session is replaced **atomically** (written aside, then renamed).
class FileTrackStore implements TrackStore {
  FileTrackStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]+$');

  @override
  Future<TrackSession?> session(String uid, String journeyId) async {
    final File file = await _file(uid, journeyId, 'session');
    if (!await file.exists()) return null;
    return _readSession(file);
  }

  @override
  Future<List<TrackSession>> sessions(String uid) async {
    final Directory dir = await _dir(uid);
    if (!await dir.exists()) return const <TrackSession>[];
    final List<TrackSession> all = <TrackSession>[];
    await for (final FileSystemEntity e in dir.list()) {
      if (e is File && e.path.endsWith('.session')) {
        final TrackSession? s = await _readSession(e);
        if (s != null) all.add(s);
      }
    }
    return all;
  }

  @override
  Future<void> eraseAccount(String uid) async {
    final Directory dir = await _dir(uid);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<void> saveSession(TrackSession session) async {
    final File file = await _file(session.uid, session.journeyId, 'session');
    await file.parent.create(recursive: true);
    final File aside = File('${file.path}.new');
    await aside.writeAsString(jsonEncode(session.toJson()), flush: true);
    await aside.rename(file.path);
  }

  @override
  Future<void> append(String uid, String journeyId, TrackPoint point) async {
    final File file = await _file(uid, journeyId, 'points');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(point.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<List<TrackPoint>> points(
    String uid,
    String journeyId, {
    int from = 0,
    int? limit,
  }) async {
    final File file = await _file(uid, journeyId, 'points');
    if (!await file.exists()) return const <TrackPoint>[];
    final List<TrackPoint> all = <TrackPoint>[];
    for (final String line in await file.readAsLines()) {
      final TrackPoint? p = _readPoint(line);
      if (p != null) all.add(p);
    }
    if (from >= all.length) return const <TrackPoint>[];
    final int end = limit == null
        ? all.length
        : (from + limit).clamp(from, all.length);
    return all.sublist(from, end);
  }

  @override
  Future<void> delete(String uid, String journeyId) async {
    for (final String kind in <String>['points', 'session']) {
      final File file = await _file(uid, journeyId, kind);
      if (await file.exists()) await file.delete();
    }
  }

  Future<Directory> _dir(String uid) async {
    if (!_id.hasMatch(uid)) throw ArgumentError.value(uid, 'uid');
    return Directory('${(await _root()).path}/tracks/$uid');
  }

  Future<File> _file(String uid, String journeyId, String kind) async {
    if (!_id.hasMatch(journeyId)) {
      throw ArgumentError.value(journeyId, 'journeyId');
    }
    return File('${(await _dir(uid)).path}/$journeyId.$kind');
  }

  static Future<TrackSession?> _readSession(File file) async {
    try {
      return TrackSession.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  static TrackPoint? _readPoint(String line) {
    try {
      return TrackPoint.fromJson(jsonDecode(line) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}
