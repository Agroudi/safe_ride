import 'package:safe_ride/features/assistant/data/models/ai_message.dart';

/// The sizes SafeRide AI works within. The server enforces its own copy of
/// every limit — these keep the app from sending what would be refused, and
/// keep the conversation on this phone small. They are not what protects
/// the free-tier quota: only the server's count does that.
abstract final class AssistantLimits {
  /// Longest question, in characters.
  static const int maxMessageChars = 1000;

  /// Most earlier messages sent with a question (six exchanges).
  static const int historyMessages = 12;

  /// Most characters of earlier messages sent with a question.
  static const int historyChars = 4000;

  /// Most messages kept on this phone per account; the oldest go first.
  static const int storedMessages = 50;

  /// Questions per account per day (UTC). The server's number decides.
  static const int dailyQuestions = 20;

  /// The recent conversation to send with a new question: at most
  /// [historyMessages], oldest dropped first until it fits [historyChars].
  static List<AiMessage> historyFor(List<AiMessage> conversation) {
    final List<AiMessage> recent = conversation.length > historyMessages
        ? conversation.sublist(conversation.length - historyMessages)
        : List<AiMessage>.of(conversation);
    int chars = recent.fold(0, (int sum, AiMessage m) => sum + m.text.length);
    while (recent.isNotEmpty && chars > historyChars) {
      chars -= recent.removeAt(0).text.length;
    }
    return recent;
  }
}
