import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';
import 'package:safe_ride/features/assistant/data/repository/conversation_store.dart';

import '../assistant_fakes.dart';

void main() {
  late Directory root;
  late FileConversationStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('assistant_store');
    store = FileConversationStore(root: () async => root);
  });

  tearDown(() => root.delete(recursive: true));

  test('nothing saved: an empty conversation', () async {
    expect(await store.load('sara'), isEmpty);
  });

  test('a conversation comes back as it was saved', () async {
    final List<AiMessage> c = <AiMessage>[
      aiMessage('q1', 'How do I share my location?'),
      aiMessage('a1', 'Open Safety…', role: AiRole.assistant),
    ];
    await store.save('sara', c);
    expect(await store.load('sara'), c);
  });

  test('each account has its own; one never reads another', () async {
    await store.save('sara', <AiMessage>[aiMessage('q1', 'mine')]);
    await store.save('omar', <AiMessage>[aiMessage('q2', 'his')]);
    expect((await store.load('sara')).single.text, 'mine');
    expect((await store.load('omar')).single.text, 'his');
  });

  test('only the newest messages are kept', () async {
    await store.save('sara', <AiMessage>[
      for (int i = 0; i < 70; i++) aiMessage('m$i', 'text $i'),
    ]);
    final List<AiMessage> kept = await store.load('sara');
    expect(kept, hasLength(AssistantLimits.storedMessages));
    expect(kept.first.id, 'm20');
    expect(kept.last.id, 'm69');
  });

  test('clear and account deletion remove the file', () async {
    await store.save('sara', <AiMessage>[aiMessage('q1', 'x')]);
    await store.clear('sara');
    expect(await store.load('sara'), isEmpty);
    await store.save('sara', <AiMessage>[aiMessage('q1', 'x')]);
    await store.erase('sara');
    expect(File('${root.path}/assistant/sara.json').existsSync(), isFalse);
    await store.erase('sara'); // twice is harmless
  });

  test('a damaged file reads as empty, never as something else', () async {
    final File file = File('${root.path}/assistant/sara.json');
    await file.create(recursive: true);
    await file.writeAsString('[{"id": "q1", "role": "user"'); // cut short
    expect(await store.load('sara'), isEmpty);
  });

  test('writes run one at a time: the last save wins', () async {
    await Future.wait(<Future<void>>[
      for (int i = 1; i <= 5; i++)
        store.save('sara', <AiMessage>[
          for (int j = 0; j < i; j++) aiMessage('m$j', 't'),
        ]),
    ]);
    expect(await store.load('sara'), hasLength(5));
  });

  test('an id that could leave the folder is refused', () {
    expect(() => store.load('../x'), throwsArgumentError);
  });
}
