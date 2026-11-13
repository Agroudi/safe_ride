import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/assistant/data/models/ai_failure.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';
import 'package:safe_ride/features/assistant/data/repository/mock_assistant_repository.dart';

void main() {
  late DateTime now;
  late MockAssistantRepository mock;
  final List<(AiLanguage, String)> asked = <(AiLanguage, String)>[];

  setUp(() {
    now = DateTime.utc(2026, 11, 9, 22);
    asked.clear();
    mock = MockAssistantRepository(
      clock: () => now,
      latency: Duration.zero,
      reply: (AiLanguage l, String q) {
        asked.add((l, q));
        return 'preview';
      },
    );
  });

  AiRequest ask(String id, [String text = 'How do I plan a journey?']) =>
      AiRequest(
        requestId: id,
        text: text,
        history: const <AiMessage>[],
        language: AiLanguage.auto,
      );

  test('a placeholder answer, counted against today', () async {
    final AiReply reply = await mock.send(ask('r1'));
    expect(reply.message.role, AiRole.assistant);
    expect(reply.message.text, 'preview');
    expect(reply.usage.used, 1);
    expect(reply.usage.limit, AssistantLimits.dailyQuestions);
    expect(reply.usage.resetsAt, DateTime.utc(2026, 11, 10));
    expect(reply.suggestGetHelp, isFalse);
  });

  test('a retry of the same question is not counted twice', () async {
    await mock.send(ask('r1'));
    await mock.send(ask('r1'));
    expect((await mock.usage()).used, 1);
  });

  test('the twenty-first question of the day is refused', () async {
    for (int i = 0; i < AssistantLimits.dailyQuestions; i++) {
      await mock.send(ask('r$i'));
    }
    await expectLater(
      mock.send(ask('one more')),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure f) => f.code,
          'code',
          AiFailureCode.dailyLimit,
        ),
      ),
    );
  });

  test('a new day (UTC) starts the count again', () async {
    for (int i = 0; i < AssistantLimits.dailyQuestions; i++) {
      await mock.send(ask('r$i'));
    }
    now = now.add(const Duration(hours: 3));
    expect((await mock.send(ask('tomorrow'))).usage.used, 1);
  });

  test('told to fail, it fails once per question, in order', () async {
    mock.failures.addAll(<AiFailureCode>[
      AiFailureCode.offline,
      AiFailureCode.unavailable,
    ]);
    for (final AiFailureCode code in <AiFailureCode>[
      AiFailureCode.offline,
      AiFailureCode.unavailable,
    ]) {
      await expectLater(
        mock.send(ask('r1')),
        throwsA(isA<AiFailure>().having((AiFailure f) => f.code, 'code', code)),
      );
    }
    expect((await mock.send(ask('r1'))).usage.used, 1);
  });

  test('a question over the limit is refused, as the server will', () async {
    await expectLater(
      mock.send(ask('r1', 'x' * (AssistantLimits.maxMessageChars + 1))),
      throwsA(
        isA<AiFailure>().having(
          (AiFailure f) => f.code,
          'code',
          AiFailureCode.tooLong,
        ),
      ),
    );
  });

  test(
    'emergency words are flagged, the way the server will flag them',
    () async {
      expect(
        (await mock.send(ask('r1', 'I had an accident'))).suggestGetHelp,
        isTrue,
      );
    },
  );

  test('it answers no question: the reply is the preview line', () async {
    await mock.send(ask('r1', 'كيف أشارك موقعي؟'));
    expect(asked.single.$2, 'كيف أشارك موقعي؟');
  });
}
