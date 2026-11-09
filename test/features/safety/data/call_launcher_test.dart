import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';

import '../help_fakes.dart';

/// A phone app that never opens: it writes down what it was handed. No test
/// here reaches a real dialer, and none uses a real emergency number.
class _Phone implements PhoneDialer {
  DialOutcome outcome = DialOutcome.opened;
  final List<String> handed = <String>[];
  Completer<void>? hold;

  @override
  Future<DialOutcome> open(String number) async {
    handed.add(number);
    await hold?.future;
    return outcome;
  }
}

void main() {
  late _Phone phone;
  late RecordingComposer texts;
  late DateTime now;
  late CallLauncher calls;

  setUp(() {
    phone = _Phone();
    texts = RecordingComposer();
    now = DateTime.utc(2026, 11, 8, 9);
    calls = CallLauncher(phone, texts, clock: () => now);
  });

  group('preparing the number', () {
    test('a harmless test number is handed over as it is', () async {
      expect(await calls.open('0550000001'), DialOutcome.opened);
      expect(phone.handed, <String>['0550000001']);
    });

    test('what people type around a number is taken out', () {
      expect(DialNumber.prepare('+966 55-000 (0001)'), '+966550000001');
      expect(DialNumber.prepare(' 055.000.0001 '), '0550000001');
    });

    test('an empty number never reaches the phone app', () async {
      for (final String empty in <String>['', '   ', '-()']) {
        expect(await calls.open(empty), DialOutcome.invalidNumber);
      }
      expect(phone.handed, isEmpty);
    });

    test('a malformed number never reaches the phone app', () async {
      for (final String bad in <String>[
        '5',
        '12a4',
        '++9665',
        '966+55',
        '*#06#',
        '1234567890123456',
        'tel:0550000001',
      ]) {
        expect(await calls.open(bad), DialOutcome.invalidNumber, reason: bad);
      }
      expect(phone.handed, isEmpty);
    });
  });

  group('what the phone app said', () {
    for (final DialOutcome outcome in <DialOutcome>[
      DialOutcome.noDialer,
      DialOutcome.failed,
    ]) {
      test('${outcome.name} is reported as it is, and can be tried again at '
          'once', () async {
        phone.outcome = outcome;
        expect(await calls.open('0550000001'), outcome);
        phone.outcome = DialOutcome.opened;
        expect(await calls.open('0550000001'), DialOutcome.opened);
        expect(phone.handed, hasLength(2));
      });
    }

    test('"opened" is the most SafeRide can know: there is no outcome for a '
        'call placed, connected or answered', () {
      expect(DialOutcome.values.map((DialOutcome o) => o.name), <String>[
        'opened',
        'invalidNumber',
        'noDialer',
        'failed',
      ]);
    });
  });

  group('one launch at a time', () {
    test('a second tap while the phone app is opening does nothing', () async {
      phone.hold = Completer<void>();
      final Future<DialOutcome?> first = calls.open('0550000001');
      expect(await calls.open('0550000001'), isNull);
      expect(await calls.open('0550000002'), isNull);
      phone.hold!.complete();
      expect(await first, DialOutcome.opened);
      expect(phone.handed, <String>['0550000001']);
    });

    test('a tap landing twice right after it opened does nothing', () async {
      expect(await calls.open('0550000001'), DialOutcome.opened);
      now = now.add(const Duration(milliseconds: 600));
      expect(await calls.open('0550000001'), isNull);
      now = now.add(calls.cooldown);
      expect(await calls.open('0550000001'), DialOutcome.opened);
      expect(phone.handed, hasLength(2));
    });

    test('cancelling in the phone app needs nothing from SafeRide: the next '
        'Call works once the cooldown has passed', () async {
      await calls.open('0550000001');
      // The user cancels in their phone app and comes back.
      now = now.add(const Duration(seconds: 5));
      expect(await calls.open('0550000001'), DialOutcome.opened);
    });
  });

  group('Batch 21: messaging a saved number', () {
    const String body =
        'I may need assistance. Please contact me as soon as possible.';

    test('the messaging app gets the prepared number and the text exactly as '
        'given: nothing added, no location', () async {
      expect(
        await calls.message('+966 55-000 (0001)', body),
        ComposeOutcome.opened,
      );
      expect(texts.composed, <(String, String)>[('+966550000001', body)]);
      expect(phone.handed, isEmpty, reason: 'texting never dials');
    });

    test(
      'a missing or malformed number never reaches the messaging app',
      () async {
        for (final String bad in <String>[
          '',
          '  ',
          '12a4',
          '1234567890123456',
        ]) {
          expect(
            await calls.message(bad, body),
            ComposeOutcome.invalidNumber,
            reason: bad,
          );
        }
        expect(texts.composed, isEmpty);
      },
    );

    for (final ComposeOutcome outcome in <ComposeOutcome>[
      ComposeOutcome.noMessaging,
      ComposeOutcome.failed,
    ]) {
      test('${outcome.name} is reported as it is, and can be tried again at '
          'once', () async {
        texts.outcome = outcome;
        expect(await calls.message('0550000001', body), outcome);
        texts.outcome = ComposeOutcome.opened;
        expect(await calls.message('0550000001', body), ComposeOutcome.opened);
      });
    }

    test('"opened" is the most SafeRide can know: no outcome says sent or '
        'delivered', () {
      expect(ComposeOutcome.values.map((ComposeOutcome o) => o.name), <String>[
        'opened',
        'invalidNumber',
        'noMessaging',
        'failed',
      ]);
    });

    test('one launch at a time across Call and Message: a text right after '
        'the phone app opened is a duplicate tap', () async {
      expect(await calls.open('0550000001'), DialOutcome.opened);
      expect(await calls.message('0550000001', body), isNull);
      now = now.add(calls.cooldown);
      expect(await calls.message('0550000001', body), ComposeOutcome.opened);
      expect(texts.composed, hasLength(1));
    });
  });

  group('Batch 21: the sms: link', () {
    test('Android: ?body=, the text percent-encoded, never a +', () {
      final Uri uri = UrlLauncherMessageComposer.link(
        '+966550000001',
        'Help me & call',
        ios: false,
      );
      expect(uri.toString(), 'sms:+966550000001?body=Help%20me%20%26%20call');
    });

    test('iOS: &body= after the number', () {
      expect(
        UrlLauncherMessageComposer.link(
          '0550000001',
          'Hi',
          ios: true,
        ).toString(),
        'sms:0550000001&body=Hi',
      );
    });

    test('Arabic text survives the link', () {
      const String arabic = 'قد أحتاج إلى المساعدة';
      final Uri uri = UrlLauncherMessageComposer.link(
        '0550000001',
        arabic,
        ios: false,
      );
      expect(Uri.decodeComponent(uri.toString().split('body=').last), arabic);
    });

    test('no text: the messaging app opens empty', () {
      expect(
        UrlLauncherMessageComposer.link(
          '0550000001',
          '',
          ios: false,
        ).toString(),
        'sms:0550000001',
      );
    });
  });
}
