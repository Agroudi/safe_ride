import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';

/// How many questions the account has asked today, of how many. The server's
/// count is the only one that decides; the app only shows it.
final class AiUsage extends Equatable {
  const AiUsage({
    required this.used,
    required this.limit,
    required this.resetsAt,
  });

  final int used;
  final int limit;

  /// When the count starts again (UTC).
  final DateTime resetsAt;

  int get remaining => used >= limit ? 0 : limit - used;

  @override
  List<Object?> get props => <Object?>[used, limit, resetsAt];
}

/// SafeRide AI's answer to one question.
final class AiReply extends Equatable {
  const AiReply({
    required this.message,
    required this.usage,
    this.suggestGetHelp = false,
  });

  final AiMessage message;
  final AiUsage usage;

  /// The server read the question as a possible emergency: the screen shows
  /// Get help at once. Nothing is called, sent or shared because of it.
  final bool suggestGetHelp;

  @override
  List<Object?> get props => <Object?>[message, usage, suggestGetHelp];
}
