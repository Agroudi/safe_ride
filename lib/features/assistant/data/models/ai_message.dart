import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_message.freezed.dart';
part 'ai_message.g.dart';

/// Who wrote a message in a SafeRide AI conversation.
enum AiRole { user, assistant }

/// One message of a SafeRide AI conversation, as the app keeps it — on this
/// phone only (`ConversationStore`). Provider-independent: nothing here is
/// shaped like any AI provider's request or response.
@freezed
abstract class AiMessage with _$AiMessage {
  const factory AiMessage({
    required String id,
    required AiRole role,
    required String text,

    /// When it was written (user) or received (assistant), UTC.
    required DateTime at,
  }) = _AiMessage;

  factory AiMessage.fromJson(Map<String, dynamic> json) =>
      _$AiMessageFromJson(json);
}
