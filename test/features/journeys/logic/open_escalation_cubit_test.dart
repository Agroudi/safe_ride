import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/features/journeys/logic/cubit/open_escalation_cubit.dart';

import '../../safety/help_fakes.dart';

void main() {
  late FakeGate gate;
  late OpenEscalationCubit cubit;
  final OpenEscalation open = OpenEscalation(
    checkId: 'e1-check',
    journeyId: 'j1',
    timedOutAt: DateTime.utc(2026, 11, 8, 9),
  );

  setUp(() {
    gate = FakeGate();
    cubit = OpenEscalationCubit(gate);
  });

  tearDown(() => cubit.close());

  test('nothing open: nothing shown', () async {
    await cubit.watch('j1');
    expect(cubit.state, isNull);
  });

  test('an open escalation is shown, and "I\'m okay" closes it once', () async {
    gate.open = open;
    await cubit.watch('j1');
    expect(cubit.state?.checkId, 'e1-check');

    gate.hold = Completer<void>();
    final Future<ResolveOutcome?> first = cubit.resolve();
    expect(await cubit.resolve(), isNull, reason: 'a second tap waits');
    gate.hold!.complete();
    expect(await first, ResolveOutcome.resolved);
    expect(gate.resolved, <String>['e1-check']);
    expect(cubit.state, isNull);
  });
}
