import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/assistant/data/models/ai_failure.dart';
import 'package:safe_ride/features/assistant/data/models/ai_message.dart';
import 'package:safe_ride/features/assistant/data/models/ai_reply.dart';
import 'package:safe_ride/features/assistant/data/models/ai_request.dart';
import 'package:safe_ride/features/assistant/data/models/assistant_limits.dart';
import 'package:safe_ride/features/assistant/data/models/emergency_signal.dart';

import '../assistant_fakes.dart';

void main() {
  group('messages', () {
    test('survive the phone file as they were written', () {
      final AiMessage m = aiMessage(
        'a1',
        'كيف أخطط لرحلة؟',
        role: AiRole.assistant,
      );
      expect(AiMessage.fromJson(m.toJson()), m);
    });

    test('the language codes the backend receives', () {
      expect(AiLanguage.values.map((AiLanguage l) => l.code), <String>[
        'auto',
        'en',
        'ar',
        'ar-EG',
      ]);
    });
  });

  group('usage', () {
    test('what is left, never below zero', () {
      final DateTime reset = DateTime.utc(2026, 11, 10);
      expect(AiUsage(used: 5, limit: 20, resetsAt: reset).remaining, 15);
      expect(AiUsage(used: 25, limit: 20, resetsAt: reset).remaining, 0);
    });
  });

  group('failures', () {
    test('only passing failures are worth a Retry', () {
      expect(
        AiFailureCode.values.where((AiFailureCode c) => c.retryable),
        <AiFailureCode>[
          AiFailureCode.offline,
          AiFailureCode.unavailable,
          AiFailureCode.timeout,
          AiFailureCode.unknown,
        ],
      );
    });
  });

  group('the history sent with a question', () {
    List<AiMessage> conversation(int n, {int length = 10}) => <AiMessage>[
      for (int i = 0; i < n; i++) aiMessage('m$i', 'x' * length),
    ];

    test('a short conversation goes whole', () {
      final List<AiMessage> c = conversation(4);
      expect(AssistantLimits.historyFor(c), c);
    });

    test('at most six exchanges, the newest', () {
      final List<AiMessage> h = AssistantLimits.historyFor(conversation(30));
      expect(h, hasLength(AssistantLimits.historyMessages));
      expect(h.first.id, 'm18');
      expect(h.last.id, 'm29');
    });

    test('the oldest go first until it fits the character budget', () {
      final List<AiMessage> h = AssistantLimits.historyFor(
        conversation(10, length: 900),
      );
      final int chars = h.fold(0, (int s, AiMessage m) => s + m.text.length);
      expect(chars, lessThanOrEqualTo(AssistantLimits.historyChars));
      expect(h.last.id, 'm9');
      expect(h, hasLength(4));
    });

    test('one message over the budget on its own is left out', () {
      expect(
        AssistantLimits.historyFor(conversation(1, length: 5000)),
        isEmpty,
      );
    });
  });

  group('emergency words', () {
    for (final String text in <String>[
      'I just had an accident on the highway',
      'My friend is INJURED and bleeding',
      'we crashed, please help me',
      'someone is unconscious',
      'حدث حادث على الطريق',
      'يوجد مصاب ويحتاج إلى إسعاف',
      'أحتاج النجدة',
      'الحقوني العربية اتخبطت',
      'في واحد بينزف',
      'العربية ولعت',
      'حادِثٌ', // diacritics
      'اسعاف', // bare alef
    ]) {
      test(
        'noticed: $text',
        () => expect(EmergencySignal.detect(text), isTrue),
      );
    }

    for (final String text in <String>[
      'How do I plan a journey?',
      'Why is my location not updating?',
      'كيف أشارك موقعي مع شخص؟',
      'ازاي أضيف جهة اتصال؟',
      'Accidentally deleted a contact', // not the word "accident"
    ]) {
      test('not an emergency: $text', () {
        expect(EmergencySignal.detect(text), isFalse);
      });
    }
  });

  test('the preview lines exist in both translation files, for every '
      'language SafeRide AI answers in', () {
    for (final String file in <String>['en', 'ar']) {
      final Map<String, dynamic> mock =
          ((jsonDecode(
                        File(
                          'assets/translations/$file.json',
                        ).readAsStringSync(),
                      )
                      as Map<String, dynamic>)['assistant']
                  as Map<String, dynamic>)['mock']
              as Map<String, dynamic>;
      for (final AiLanguage l in AiLanguage.values) {
        if (l == AiLanguage.auto) continue;
        expect(mock[l.name], isA<String>(), reason: '$file ${l.name}');
        expect(mock[l.name], contains('SafeRide AI'));
      }
    }
  });
}
