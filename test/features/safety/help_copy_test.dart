import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the screens after an unanswered safety check say, read straight from
/// the translation files: they must never claim that anyone was told, called
/// or is coming, and must say that nobody was contacted.
void main() {
  const List<String> subtrees = <String>[
    'safety.help',
    'journeys.escalationNote',
    'journeys.safetyCheck.followUp',
    'safety.reach',
  ];

  Map<String, dynamic> load(String language) =>
      jsonDecode(File('assets/translations/$language.json').readAsStringSync())
          as Map<String, dynamic>;

  Object? at(Map<String, dynamic> root, String path) {
    Object? node = root;
    for (final String part in path.split('.')) {
      node = (node! as Map<String, dynamic>)[part];
    }
    return node;
  }

  Map<String, String> flatten(Object? node, [String prefix = '']) {
    if (node is String) return <String, String>{prefix: node};
    final Map<String, String> out = <String, String>{};
    (node! as Map<String, dynamic>).forEach((String key, Object? value) {
      out.addAll(flatten(value, prefix.isEmpty ? key : '$prefix.$key'));
    });
    return out;
  }

  Map<String, String> strings(String language) {
    final Map<String, dynamic> root = load(language);
    return <String, String>{
      for (final String tree in subtrees) ...flatten(at(root, tree), tree),
    };
  }

  test('both languages have the same keys', () {
    expect(strings('ar').keys.toSet(), strings('en').keys.toSet());
  });

  test('English never claims anyone was told, called or is coming', () {
    const List<String> claims = <String>[
      'notified',
      'delivered',
      'accident',
      'was alerted',
      'were alerted',
      'has been alerted',
      'have been alerted',
      'was called',
      'has been called',
      'on the way',
      'on its way',
      'help is coming',
      'has been sent',
      'message sent',
      'text sent',
      'call connected',
    ];
    strings('en').forEach((String key, String text) {
      for (final String claim in claims) {
        expect(text.toLowerCase(), isNot(contains(claim)), reason: key);
      }
    });
  });

  test('Arabic never claims anyone was told, called or is coming', () {
    const List<String> claims = <String>[
      'حادث',
      'تم إبلاغ',
      'تم تنبيه',
      'تم الاتصال',
      'في الطريق',
      'تم الإرسال',
      'أُرسلت الرسالة',
    ];
    strings('ar').forEach((String key, String text) {
      for (final String claim in claims) {
        expect(text, isNot(contains(claim)), reason: key);
      }
    });
  });

  test('an open escalation says nobody was contacted, in both languages', () {
    final Map<String, String> en = strings('en');
    final Map<String, String> ar = strings('ar');
    for (final String key in <String>[
      'safety.help.open.body',
      'journeys.escalationNote.body',
    ]) {
      expect(en[key]!.toLowerCase(), contains('nobody has been contacted'));
      expect(ar[key], contains('لم يُتواصل مع أحد'));
    }
  });
}
