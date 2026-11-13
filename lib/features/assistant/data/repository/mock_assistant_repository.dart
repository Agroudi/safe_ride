import 'package:easy_localization/easy_localization.dart';
import 'package:safe_ride/features/assistant/data/models/ai_failure.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';
import 'package:safe_ride/features/assistant/data/models/emergency_signal.dart';
import 'package:safe_ride/features/assistant/data/repository/assistant_repository.dart';

/// **Local only — not SafeRide AI.** A stand-in for the backend while it does
/// not exist (AI-02 to AI-04): every answer is a fixed preview line saying so,
/// produced on this phone, and nothing leaves it. It counts questions per day
/// in memory the way the server will, so the screens can be built and tested
/// against the limit, and it can be told to fail with any [AiFailureCode].
///
/// It never pretends to know anything: it answers no question.
class MockAssistantRepository implements AssistantRepository {
  MockAssistantRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 600),
    String Function(AiLanguage language, String question)? reply,
  }) : _clock = clock ?? DateTime.now,
       _reply = reply ?? _preview;

  final DateTime Function() _clock;
  final String Function(AiLanguage, String) _reply;
  final Duration latency;

  /// Failures to throw, one per question, in order — for tests and demos.
  final List<AiFailureCode> failures = <AiFailureCode>[];

  final Set<String> _answered = <String>{};
  DateTime? _day;
  int _used = 0;

  @override
  Future<AiReply> send(AiRequest request) async {
    await Future<void>.delayed(latency);
    if (failures.isNotEmpty) throw AiFailure(failures.removeAt(0));
    if (request.text.length > AssistantLimits.maxMessageChars) {
      throw const AiFailure(AiFailureCode.tooLong);
    }
    _rollDay();
    // A retry of an answered question is not counted again.
    if (!_answered.contains(request.requestId)) {
      if (_used >= AssistantLimits.dailyQuestions) {
        throw const AiFailure(AiFailureCode.dailyLimit);
      }
      _used++;
      _answered.add(request.requestId);
    }
    final DateTime now = _clock().toUtc();
    return AiReply(
      message: AiMessage(
        id: 'mock-${request.requestId}',
        role: AiRole.assistant,
        text: _reply(request.language, request.text),
        at: now,
      ),
      usage: _usage(),
      suggestGetHelp: EmergencySignal.detect(request.text),
    );
  }

  @override
  Future<AiUsage> usage() async {
    _rollDay();
    return _usage();
  }

  void _rollDay() {
    final DateTime now = _clock().toUtc();
    final DateTime day = DateTime.utc(now.year, now.month, now.day);
    if (_day != day) {
      _day = day;
      _used = 0;
      _answered.clear();
    }
  }

  AiUsage _usage() => AiUsage(
    used: _used,
    limit: AssistantLimits.dailyQuestions,
    resetsAt: _day!.add(const Duration(days: 1)),
  );

  /// The preview line in the language asked for; "auto" follows the script
  /// the question is written in.
  static String _preview(AiLanguage language, String question) {
    final AiLanguage resolved = language == AiLanguage.auto
        ? (RegExp('[؀-ۿ]').hasMatch(question)
              ? AiLanguage.arabicMsa
              : AiLanguage.english)
        : language;
    return 'assistant.mock.${resolved.name}'.tr();
  }
}
