import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/assistant/data/models/ai_failure.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';

/// The SafeRide AI screen: the conversation, whether a question is on its
/// way, why the last one failed, today's count, the language, and whether to
/// offer Get help.
final class AssistantState extends Equatable {
  const AssistantState({
    this.loading = true,
    this.messages = const <AiMessage>[],
    this.sending = false,
    this.failure,
    this.pending,
    this.usage,
    this.language = AiLanguage.auto,
    this.getHelp = false,
  });

  final bool loading;

  /// Oldest first.
  final List<AiMessage> messages;

  /// A question is on its way; another waits.
  final bool sending;

  /// Why the last question got no answer; null when it did.
  final AiFailureCode? failure;

  /// The unanswered question, kept for Retry with its own request id.
  final AiRequest? pending;

  /// Today's count, once the server (or the mock) has said it.
  final AiUsage? usage;
  final AiLanguage language;

  /// Something the user wrote may mean an emergency: show Get help. It is
  /// shown, never acted on.
  final bool getHelp;

  bool get canRetry =>
      pending != null && !sending && (failure?.retryable ?? false);

  AssistantState copyWith({
    bool? loading,
    List<AiMessage>? messages,
    bool? sending,
    AiFailureCode? Function()? failure,
    AiRequest? Function()? pending,
    AiUsage? usage,
    AiLanguage? language,
    bool? getHelp,
  }) => AssistantState(
    loading: loading ?? this.loading,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    failure: failure == null ? this.failure : failure(),
    pending: pending == null ? this.pending : pending(),
    usage: usage ?? this.usage,
    language: language ?? this.language,
    getHelp: getHelp ?? this.getHelp,
  );

  @override
  List<Object?> get props => <Object?>[
    loading,
    messages,
    sending,
    failure,
    pending,
    usage,
    language,
    getHelp,
  ];
}
