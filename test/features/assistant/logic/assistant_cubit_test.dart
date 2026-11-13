import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/assistant/data/models/ai_failure.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';
import 'package:safe_ride/features/assistant/data/repository/assistant_repository.dart';
import 'package:safe_ride/features/assistant/data/repository/mock_assistant_repository.dart';
import 'package:safe_ride/features/assistant/logic/cubit/assistant_cubit.dart';

import '../assistant_fakes.dart';

/// An assistant whose answer waits until the test lets it go, recording
/// every request it was given.
class _Held implements AssistantRepository {
  final List<AiRequest> requests = <AiRequest>[];
  Completer<AiReply>? next;

  @override
  Future<AiReply> send(AiRequest request) {
    requests.add(request);
    return (next = Completer<AiReply>()).future;
  }

  @override
  Future<AiUsage> usage() async =>
      AiUsage(used: 0, limit: 20, resetsAt: DateTime.utc(2026, 11, 10));
}

void main() {
  final DateTime now = DateTime.utc(2026, 11, 9, 10);
  late AssistantSession session;
  late MemoryConversationStore store;
  late MockAssistantRepository mock;
  late AssistantCubit cubit;
  int ids = 0;

  AssistantCubit make(AssistantRepository assistant) => AssistantCubit(
    session,
    store,
    assistant,
    clock: () => now,
    newId: () => 'q${++ids}',
  );

  setUp(() {
    ids = 0;
    session = AssistantSession();
    store = MemoryConversationStore();
    mock = MockAssistantRepository(
      clock: () => now,
      latency: Duration.zero,
      reply: (_, _) => 'preview',
    );
    cubit = make(mock);
  });

  tearDown(() => cubit.close());

  test(
    'opening loads this account\'s conversation and today\'s count',
    () async {
      store.byAccount['sara'] = <AiMessage>[aiMessage('old', 'earlier')];
      await cubit.load();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.messages.single.id, 'old');
      expect(cubit.state.usage?.used, 0);
    },
  );

  test('signed out: nothing loads, and it says so', () async {
    session.uid = null;
    await cubit.load();
    expect(cubit.state.failure, AiFailureCode.unauthenticated);
    expect(cubit.state.messages, isEmpty);
  });

  test('a question and its answer, both kept on the phone', () async {
    await cubit.load();
    await cubit.send('  How do I share my location?  ');
    final List<AiMessage> m = cubit.state.messages;
    expect(m.map((AiMessage x) => x.role), <AiRole>[
      AiRole.user,
      AiRole.assistant,
    ]);
    expect(m.first.text, 'How do I share my location?');
    expect(m.last.text, 'preview');
    expect(cubit.state.sending, isFalse);
    expect(cubit.state.pending, isNull);
    expect(cubit.state.usage?.used, 1);
    expect(store.byAccount['sara'], m);
  });

  test('blank text is ignored', () async {
    await cubit.load();
    await cubit.send('   ');
    expect(cubit.state.messages, isEmpty);
    expect(store.saves, 0);
  });

  test('a question over the limit is refused here, before sending', () async {
    await cubit.load();
    await cubit.send('x' * (AssistantLimits.maxMessageChars + 1));
    expect(cubit.state.failure, AiFailureCode.tooLong);
    expect(cubit.state.messages, isEmpty);
    expect((await mock.usage()).used, 0);
  });

  test(
    'one question at a time: a second tap while sending does nothing',
    () async {
      final _Held held = _Held();
      cubit = make(held);
      await cubit.load();
      final Future<void> first = cubit.send('first');
      await pumpEventQueue();
      expect(cubit.state.sending, isTrue);
      await cubit.send('second');
      expect(held.requests, hasLength(1));
      held.next!.complete(
        AiReply(
          message: aiMessage('a1', 'answer', role: AiRole.assistant),
          usage: AiUsage(
            used: 1,
            limit: 20,
            resetsAt: DateTime.utc(2026, 11, 10),
          ),
        ),
      );
      await first;
      expect(cubit.state.messages.map((AiMessage m) => m.text), <String>[
        'first',
        'answer',
      ]);
    },
  );

  test(
    'the history sent is the recent conversation, never the new question',
    () async {
      final _Held held = _Held();
      cubit = make(held);
      store.byAccount['sara'] = <AiMessage>[
        for (int i = 0; i < 20; i++) aiMessage('m$i', 'message $i'),
      ];
      await cubit.load();
      unawaited(cubit.send('new question'));
      await pumpEventQueue();
      final AiRequest sent = held.requests.single;
      expect(sent.text, 'new question');
      expect(sent.history, hasLength(AssistantLimits.historyMessages));
      expect(sent.history.last.id, 'm19');
      expect(
        sent.history.any((AiMessage m) => m.text == 'new question'),
        isFalse,
      );
    },
  );

  test(
    'a passing failure keeps the question for Retry, with the same id',
    () async {
      mock.failures.add(AiFailureCode.offline);
      await cubit.load();
      await cubit.send('Why is my location not updating?');
      expect(cubit.state.failure, AiFailureCode.offline);
      expect(cubit.state.canRetry, isTrue);
      expect(cubit.state.messages.single.role, AiRole.user);
      final String id = cubit.state.pending!.requestId;

      await cubit.retry();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.messages.last.id, 'mock-$id');
      expect(cubit.state.usage?.used, 1, reason: 'counted once');
    },
  );

  test('a lasting failure offers no Retry', () async {
    mock.failures.add(AiFailureCode.dailyLimit);
    await cubit.load();
    await cubit.send('one more');
    expect(cubit.state.failure, AiFailureCode.dailyLimit);
    expect(cubit.state.canRetry, isFalse);
    await cubit.retry();
    expect(cubit.state.failure, AiFailureCode.dailyLimit);
  });

  test('an unexpected error reads as unknown, never as a crash', () async {
    cubit = make(_Throwing());
    await cubit.load();
    await cubit.send('hello');
    expect(cubit.state.failure, AiFailureCode.unknown);
    expect(cubit.state.sending, isFalse);
  });

  test('emergency words offer Get help at once — before any answer', () async {
    final _Held held = _Held();
    cubit = make(held);
    await cubit.load();
    unawaited(cubit.send('I had an accident'));
    await pumpEventQueue();
    expect(cubit.state.sending, isTrue);
    expect(cubit.state.getHelp, isTrue);
    cubit.dismissGetHelp();
    expect(cubit.state.getHelp, isFalse);
  });

  test('the server can offer Get help too', () async {
    await cubit.load();
    await cubit.send('حدث حادث');
    expect(cubit.state.getHelp, isTrue);
  });

  test('clearing empties the screen and the phone', () async {
    await cubit.load();
    await cubit.send('hello');
    await cubit.clear();
    expect(cubit.state.messages, isEmpty);
    expect(store.byAccount['sara'], isNull);
  });

  test('the chosen language goes with the question', () async {
    final _Held held = _Held();
    cubit = make(held);
    await cubit.load();
    cubit.setLanguage(AiLanguage.arabicEgyptian);
    unawaited(cubit.send('ازاي أبدأ رحلة؟'));
    await pumpEventQueue();
    expect(held.requests.single.language, AiLanguage.arabicEgyptian);
  });

  test('another account never sees this conversation', () async {
    await cubit.load();
    await cubit.send('mine');
    session.uid = 'omar';
    final AssistantCubit other = make(mock);
    addTearDown(other.close);
    await other.load();
    expect(other.state.messages, isEmpty);
  });
}

class _Throwing implements AssistantRepository {
  @override
  Future<AiReply> send(AiRequest request) => throw StateError('boom');

  @override
  Future<AiUsage> usage() => throw StateError('boom');
}
