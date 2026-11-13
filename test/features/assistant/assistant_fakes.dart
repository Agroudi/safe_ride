import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/repository/conversation_store.dart';

/// A conversation store in memory, counting writes.
class MemoryConversationStore implements ConversationStore {
  final Map<String, List<AiMessage>> byAccount = <String, List<AiMessage>>{};
  int saves = 0;

  @override
  Future<List<AiMessage>> load(String uid) async =>
      List<AiMessage>.of(byAccount[uid] ?? const <AiMessage>[]);

  @override
  Future<void> save(String uid, List<AiMessage> messages) async {
    saves++;
    byAccount[uid] = List<AiMessage>.of(messages);
  }

  @override
  Future<void> clear(String uid) async => byAccount.remove(uid);

  @override
  Future<void> erase(String uid) => clear(uid);
}

/// Signed in as [uid], or signed out when it is null.
class AssistantSession implements SessionReader {
  AssistantSession([this.uid = 'sara']);

  String? uid;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara Ahmed');
}

AiMessage aiMessage(
  String id,
  String text, {
  AiRole role = AiRole.user,
  DateTime? at,
}) => AiMessage(
  id: id,
  role: role,
  text: text,
  at: at ?? DateTime.utc(2026, 11, 9, 10),
);
