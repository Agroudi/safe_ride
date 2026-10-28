import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/platform/launch_handoff.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';

/// The splash intro holds frame 0 until Android has removed its system
/// splash, and never waits for it forever.
void main() {
  const MethodChannel channel = MethodChannel('safe_ride/launch');

  setUp(() => LaunchHandoff.enabled = true);
  tearDown(() {
    LaunchHandoff.enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void answer(Future<void> Function() reply) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'handedOff');
            await reply();
            return null;
          });

  /// The entrance clock of a scope gated on the hand-off.
  Future<Animation<double>> gated(WidgetTester tester) async {
    late Animation<double> clock;
    await tester.pumpWidget(
      EntranceScope(
        duration: const Duration(milliseconds: 600),
        startWhen: LaunchHandoff.wait(),
        child: Builder(
          builder: (BuildContext context) {
            clock = EntranceScope.maybeOf(context)!;
            return const SizedBox();
          },
        ),
      ),
    );
    return clock;
  }

  testWidgets('holds frame 0 until the system splash is gone', (tester) async {
    final Completer<void> removed = Completer<void>();
    answer(() => removed.future);
    final Animation<double> clock = await gated(tester);

    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.value, 0);

    removed.complete();
    // A channel reply arrives on the real event loop, not in fake time.
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(clock.value, greaterThan(0));
  });

  testWidgets('starts anyway after the timeout', (tester) async {
    answer(() => Completer<void>().future);
    final Animation<double> clock = await gated(tester);

    await tester.pump(LaunchHandoff.timeout - const Duration(milliseconds: 1));
    expect(clock.value, 0);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(clock.value, greaterThan(0));
  });

  testWidgets('starts at once when the hand-off already happened', (
    tester,
  ) async {
    answer(() async {});
    final Animation<double> clock = await gated(tester);
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clock.value, greaterThan(0));
  });

  test('does not wait off Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(LaunchHandoff.wait(), isA<SynchronousFuture<void>>());
    debugDefaultTargetPlatformOverride = null;
  });
}
