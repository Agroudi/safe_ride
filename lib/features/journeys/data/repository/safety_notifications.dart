import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';

/// Whether SafeRide can show a safety notification on this phone.
enum SafetyNoticeAccess {
  allowed,

  /// Refused, never asked, or the safety channel is switched off in the
  /// phone's settings: a safety check can then be answered only with the
  /// app on screen.
  blocked,
}

/// The safety check outside the app: what the user sees when SafeRide is
/// not on screen. `LocalSafetyNotifications` implements it.
abstract interface class SafetyNotifications {
  /// Creates the channels, in the app's language, and starts listening.
  Future<void> prepare();

  /// "Are you okay?", counting down to [check]'s deadline, with "I'm safe".
  /// False when the phone would not show it (notifications off, the channel
  /// blocked, the deadline passed): asking is not showing.
  Future<bool> asking(SafetyCheck check);

  /// Replaces it: no answer was recorded for [check]. False as for [asking].
  Future<bool> noAnswer(SafetyCheck check);

  /// Removes whichever is showing.
  Future<void> clear();

  Future<SafetyNoticeAccess> access();

  /// Asks the phone, once; afterwards only [openSettings] can change it.
  Future<SafetyNoticeAccess> request();

  Future<void> openSettings();

  /// Fires when an answer may be waiting in [takeAnswers].
  Stream<void> get answered;

  /// The "I'm safe" taps made on a notification, by check id, each with
  /// the moment of the tap (UTC) — removed as they are read.
  Future<Map<String, DateTime>> takeAnswers();
}

/// The "I'm safe" taps not yet applied: one small file per check. A tap on a
/// notification runs in its own isolate — possibly with the app's process
/// just started and no service to tell — so it is written down first, and
/// the service reads it (at once, or on the next launch). Without this, a
/// user who answered in time could still reach their contacts as "no
/// answer".
class SafetyAnswerInbox {
  SafetyAnswerInbox({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]+$');

  final Future<Directory> Function() _root;

  Future<Directory> _directory() async =>
      Directory('${(await _root()).path}/safety_checks/answers');

  Future<void> put(String checkId, DateTime at) async {
    if (!_id.hasMatch(checkId)) throw ArgumentError.value(checkId, 'checkId');
    final Directory directory = await _directory();
    await directory.create(recursive: true);
    // Aside, then renamed: the app may read at this very moment.
    final File aside = File('${directory.path}/$checkId.new');
    await aside.writeAsString(at.toUtc().toIso8601String(), flush: true);
    await aside.rename('${directory.path}/$checkId');
  }

  Future<Map<String, DateTime>> take() async {
    final Directory directory = await _directory();
    if (!await directory.exists()) return <String, DateTime>{};
    final Map<String, DateTime> answers = <String, DateTime>{};
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File || entity.path.endsWith('.new')) continue;
      final DateTime? at = DateTime.tryParse(await entity.readAsString());
      if (at != null) answers[entity.uri.pathSegments.last] = at.toUtc();
      await entity.delete();
    }
    return answers;
  }
}
