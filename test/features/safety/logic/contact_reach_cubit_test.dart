import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_reach_cubit.dart';

import '../help_fakes.dart';

/// A messaging app that opens only when the test lets it.
class _Slow extends RecordingComposer {
  final Completer<void> gate = Completer<void>();

  @override
  Future<ComposeOutcome> compose(String number, String body) async {
    await gate.future;
    return super.compose(number, body);
  }
}

void main() {
  late RecordingDialer dialer;

  setUp(() => dialer = RecordingDialer());

  test('Call opens the phone app with the prepared number', () async {
    final ContactReachCubit cubit = ContactReachCubit(
      CallLauncher(dialer, RecordingComposer()),
    );
    addTearDown(cubit.close);
    expect(await cubit.call('c1', '+966 55 000 0001'), DialOutcome.opened);
    expect(dialer.opened, <String>['+966550000001']);
    expect(cubit.state, isNull);
  });

  test('Message opens the messaging app with the text as given', () async {
    final RecordingComposer texts = RecordingComposer();
    final ContactReachCubit cubit = ContactReachCubit(
      CallLauncher(dialer, texts),
    );
    addTearDown(cubit.close);
    expect(await cubit.message('c1', '0550000001', ''), ComposeOutcome.opened);
    expect(texts.composed, <(String, String)>[('0550000001', '')]);
    expect(dialer.opened, isEmpty);
  });

  test('while one app is opening, the contact is busy and a second tap — on '
      'either button — does nothing', () async {
    final _Slow texts = _Slow();
    final ContactReachCubit cubit = ContactReachCubit(
      CallLauncher(dialer, texts),
    );
    addTearDown(cubit.close);
    final Future<ComposeOutcome?> first = cubit.message('c1', '0550000001', '');
    expect(cubit.state, 'c1');
    expect(await cubit.call('c1', '0550000001'), isNull);
    expect(await cubit.message('c2', '0550000002', ''), isNull);
    texts.gate.complete();
    expect(await first, ComposeOutcome.opened);
    expect(cubit.state, isNull);
    expect(dialer.opened, isEmpty);
    expect(texts.composed, hasLength(1));
  });

  test('an unusable number reaches neither app', () async {
    final RecordingComposer texts = RecordingComposer();
    final ContactReachCubit cubit = ContactReachCubit(
      CallLauncher(dialer, texts),
    );
    addTearDown(cubit.close);
    expect(await cubit.call('c1', '12a4'), DialOutcome.invalidNumber);
    expect(await cubit.message('c1', '', ''), ComposeOutcome.invalidNumber);
    expect(dialer.opened, isEmpty);
    expect(texts.composed, isEmpty);
  });
}
