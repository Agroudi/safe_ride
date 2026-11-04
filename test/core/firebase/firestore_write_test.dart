import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/firebase/firestore_write.dart';

void main() {
  test('a write the server confirms is synced', () async {
    expect(await settle(Future<void>.value()), isTrue);
  });

  // testWidgets for its fake clock: the wait passes without real time.
  testWidgets('a write still queued after the wait is saved, not synced', (
    WidgetTester tester,
  ) async {
    bool? synced;
    unawaited(settle(Completer<void>().future).then((bool s) => synced = s));
    await tester.pump(AppDurations.syncWait - const Duration(milliseconds: 1));
    expect(synced, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(synced, isFalse);
  });

  test('a rejection that arrives in time is thrown', () async {
    expect(settle(Future<void>.error(StateError('denied'))), throwsStateError);
  });
}
