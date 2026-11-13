import 'package:equatable/equatable.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';

/// The language SafeRide AI answers in. [auto] follows the language the user
/// writes in; the others are the user's own choice.
enum AiLanguage {
  auto('auto'),
  english('en'),
  arabicMsa('ar'),
  arabicEgyptian('ar-EG');

  const AiLanguage(this.code);

  /// What the backend receives.
  final String code;
}

/// One question for SafeRide AI, as the app sends it: the new text, the
/// recent conversation, and the language. No location, contact, token or
/// account detail is ever part of it.
final class AiRequest extends Equatable {
  const AiRequest({
    required this.requestId,
    required this.text,
    required this.history,
    required this.language,
  });

  /// Unique per question and kept across retries, so the server never counts
  /// one question twice.
  final String requestId;
  final String text;

  /// Earlier messages, oldest first, already trimmed (`AssistantLimits`).
  final List<AiMessage> history;
  final AiLanguage language;

  @override
  List<Object?> get props => <Object?>[requestId, text, history, language];
}
