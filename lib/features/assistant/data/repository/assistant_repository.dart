import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';

/// SafeRide AI as the app sees it — the seam between the app and whatever
/// answers. Provider-independent: no Gemini (or other provider) type crosses
/// it, so a provider can change at the server without touching the app.
///
/// Implementations: `MockAssistantRepository` (local, for development until
/// the backend exists). Later, `CallableAssistantRepository` over the
/// SafeRide backend, which alone holds the provider's key, verifies the
/// account and App Check, and counts every question. The app never talks to
/// an AI provider itself.
///
/// Every failure is an `AiFailure`.
abstract interface class AssistantRepository {
  /// Asks [request]; the answer, or an `AiFailure`.
  Future<AiReply> send(AiRequest request);

  /// Today's count for the signed-in account.
  Future<AiUsage> usage();
}
