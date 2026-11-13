import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';

/// The SafeRide AI conversation, kept **on this phone only**, one per
/// account. Nothing of it is stored by SafeRide's servers. Deleting the
/// account erases it ([AccountData]); signing out keeps it for that account,
/// like the rest of the account's files on the phone.
abstract interface class ConversationStore implements AccountData {
  Future<List<AiMessage>> load(String uid);

  /// Replaces the stored conversation with [messages], keeping the newest
  /// `AssistantLimits.storedMessages`.
  Future<void> save(String uid, List<AiMessage> messages);

  Future<void> clear(String uid);
}

/// [ConversationStore] in the app's private support directory
/// (`assistant/<uid>.json`): written whole, through a temporary file and a
/// rename, one write at a time. A damaged file reads as an empty
/// conversation, never as a wrong one.
class FileConversationStore implements ConversationStore {
  FileConversationStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]+$');

  final Future<Directory> Function() _root;
  Future<void> _queue = Future<void>.value();

  @override
  Future<List<AiMessage>> load(String uid) async {
    final File file = await _file(uid);
    if (!await file.exists()) return <AiMessage>[];
    try {
      return <AiMessage>[
        for (final Object? e in jsonDecode(await file.readAsString()) as List)
          AiMessage.fromJson(e! as Map<String, dynamic>),
      ];
    } on Object {
      return <AiMessage>[];
    }
  }

  @override
  Future<void> save(String uid, List<AiMessage> messages) => _enqueue(() async {
    final List<AiMessage> kept =
        messages.length > AssistantLimits.storedMessages
        ? messages.sublist(messages.length - AssistantLimits.storedMessages)
        : messages;
    final File file = await _file(uid);
    await file.parent.create(recursive: true);
    final File aside = File('${file.path}.new');
    await aside.writeAsString(
      jsonEncode(<Object?>[for (final AiMessage m in kept) m.toJson()]),
      flush: true,
    );
    await aside.rename(file.path);
  });

  @override
  Future<void> clear(String uid) => _enqueue(() async {
    final File file = await _file(uid);
    if (await file.exists()) await file.delete();
  });

  @override
  Future<void> erase(String uid) => clear(uid);

  Future<void> _enqueue(Future<void> Function() work) {
    final Future<void> done = _queue.then((_) => work());
    _queue = done.catchError((Object _) {});
    return done;
  }

  Future<File> _file(String uid) async {
    if (!_id.hasMatch(uid)) throw ArgumentError.value(uid, 'uid');
    return File('${(await _root()).path}/assistant/$uid.json');
  }
}
