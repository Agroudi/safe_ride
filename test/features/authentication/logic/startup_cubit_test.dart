import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/startup_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An [AuthRepository] whose answer each test scripts, counting the calls so a
/// test can prove the session store was never asked.
class _FakeAuthRepository extends Fake implements AuthRepository {
  _FakeAuthRepository(this._answers);

  /// Answers true or false at once.
  factory _FakeAuthRepository.signedIn(bool value) =>
      _FakeAuthRepository(<Future<bool> Function()>[() async => value]);

  /// Fails the way a broken keystore would.
  factory _FakeAuthRepository.throwing(Object error) =>
      _FakeAuthRepository(<Future<bool> Function()>[() async => throw error]);

  /// Answers with [future] — one that may never complete.
  factory _FakeAuthRepository.answering(Future<bool> future) =>
      _FakeAuthRepository(<Future<bool> Function()>[() => future]);

  /// One answer per call, the last one repeated.
  final List<Future<bool> Function()> _answers;
  int calls = 0;

  @override
  Future<bool> hasSession() {
    final int index = calls < _answers.length ? calls : _answers.length - 1;
    calls++;
    return _answers[index]();
  }
}

/// Records errors reported to blocs — an emit after `close` lands here.
class _ErrorObserver extends BlocObserver {
  final List<Object> errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

Future<StartupCubit> _cubit(
  AuthRepository auth, {
  required bool onboarded,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (onboarded) 'prefs.onboardingCompleted': true,
  });
  final StartupCubit cubit = StartupCubit(
    AppPreferences(await SharedPreferences.getInstance()),
    auth,
  );
  addTearDown(cubit.close);
  return cubit;
}

/// Runs [StartupCubit.decide] and returns every state it emitted, in order.
Future<List<StartupState>> _decide(StartupCubit cubit) async {
  final List<StartupState> states = <StartupState>[];
  final StreamSubscription<StartupState> subscription = cubit.stream.listen(
    states.add,
  );
  await cubit.decide();
  // The state stream is asynchronous: let it deliver before reading.
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  return states;
}

void main() {
  test('starts loading', () async {
    final StartupCubit cubit = await _cubit(
      _FakeAuthRepository.signedIn(true),
      onboarded: true,
    );

    expect(cubit.state, const StartupLoading());
  });

  test('first launch opens onboarding, session store untouched', () async {
    final _FakeAuthRepository auth = _FakeAuthRepository.signedIn(true);
    final StartupCubit cubit = await _cubit(auth, onboarded: false);

    expect(await _decide(cubit), const <StartupState>[
      StartupLoading(),
      StartupReady(StartupDestination.onboarding),
    ]);
    expect(auth.calls, 0);
  });

  test('onboarded with no session opens welcome', () async {
    final _FakeAuthRepository auth = _FakeAuthRepository.signedIn(false);
    final StartupCubit cubit = await _cubit(auth, onboarded: true);

    expect(await _decide(cubit), const <StartupState>[
      StartupLoading(),
      StartupReady(StartupDestination.welcome),
    ]);
    expect(auth.calls, 1);
  });

  test('onboarded with a session opens home', () async {
    final StartupCubit cubit = await _cubit(
      _FakeAuthRepository.signedIn(true),
      onboarded: true,
    );

    expect(await _decide(cubit), const <StartupState>[
      StartupLoading(),
      StartupReady(StartupDestination.home),
    ]);
  });

  group('a session check that fails', () {
    // An Error as well as an Exception: a keystore plugin can throw either,
    // and either one left uncaught would leave the splash spinning.
    final Map<String, Object> errors = <String, Object>{
      'an Exception': Exception('keystore'),
      'an Error': StateError('keystore'),
    };
    for (final MapEntry<String, Object> error in errors.entries) {
      test('fails on ${error.key}', () async {
        final StartupCubit cubit = await _cubit(
          _FakeAuthRepository.throwing(error.value),
          onboarded: true,
        );

        expect(await _decide(cubit), const <StartupState>[
          StartupLoading(),
          StartupFailed(),
        ]);
      });
    }

    test('recovers on retry', () async {
      final _FakeAuthRepository auth = _FakeAuthRepository(
        <Future<bool> Function()>[
          () async => throw Exception('keystore'),
          () async => true,
        ],
      );
      final StartupCubit cubit = await _cubit(auth, onboarded: true);

      expect(await _decide(cubit), const <StartupState>[
        StartupLoading(),
        StartupFailed(),
      ]);
      expect(await _decide(cubit), const <StartupState>[
        StartupLoading(),
        StartupReady(StartupDestination.home),
      ]);
      expect(auth.calls, 2);
    });
  });

  // `testWidgets` runs in fake time, so the startup timeout is crossed with
  // `pump` instead of a real wait — and with no extra package.
  group('the timeout', () {
    testWidgets('a check that never answers fails once it elapses', (
      WidgetTester tester,
    ) async {
      final StartupCubit cubit = await _cubit(
        _FakeAuthRepository.answering(Completer<bool>().future),
        onboarded: true,
      );

      final Future<void> pending = cubit.decide();
      await tester.pump(
        AppDurations.startupTimeout - const Duration(milliseconds: 1),
      );
      expect(cubit.state, const StartupLoading());

      // Checked before awaiting: without a timeout, `pending` never completes
      // and the test would hang instead of failing.
      await tester.pump(const Duration(milliseconds: 1));
      expect(cubit.state, const StartupFailed());
      await pending;
    });

    testWidgets('a slow check that answers in time still decides', (
      WidgetTester tester,
    ) async {
      final Duration slow =
          AppDurations.startupTimeout - const Duration(seconds: 1);
      final StartupCubit cubit = await _cubit(
        _FakeAuthRepository.answering(Future<bool>.delayed(slow, () => true)),
        onboarded: true,
      );

      final Future<void> pending = cubit.decide();
      await tester.pump(slow);
      expect(cubit.state, const StartupReady(StartupDestination.home));
      await pending;
    });
  });

  // A retry that fails again at once would change nothing on screen: it stays
  // loading for a moment, so the attempt is seen. The first decision is never
  // padded.
  group('the retry minimum', () {
    testWidgets('a retry that fails at once stays loading until it passes', (
      WidgetTester tester,
    ) async {
      final StartupCubit cubit = await _cubit(
        _FakeAuthRepository.throwing(Exception('keystore')),
        onboarded: true,
      );

      final Future<void> pending = cubit.decide(retry: true);
      await tester.pump(
        AppDurations.startupRetryMinimum - const Duration(milliseconds: 1),
      );
      expect(cubit.state, const StartupLoading());

      await tester.pump(const Duration(milliseconds: 1));
      expect(cubit.state, const StartupFailed());
      await pending;
    });

    testWidgets('a first decision is not held', (WidgetTester tester) async {
      final StartupCubit cubit = await _cubit(
        _FakeAuthRepository.throwing(Exception('keystore')),
        onboarded: true,
      );

      final Future<void> pending = cubit.decide();
      await tester.pump();
      expect(cubit.state, const StartupFailed());
      await pending;
    });
  });

  // The splash can be disposed while the check is in flight; the late answer
  // must be dropped, not emitted into a closed cubit.
  group('closed while checking', () {
    late _ErrorObserver observer;

    setUp(() {
      final BlocObserver previous = Bloc.observer;
      observer = _ErrorObserver();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previous);
    });

    for (final bool succeeds in <bool>[true, false]) {
      test('drops a late ${succeeds ? 'answer' : 'failure'}', () async {
        final Completer<bool> answer = Completer<bool>();
        final StartupCubit cubit = await _cubit(
          _FakeAuthRepository.answering(answer.future),
          onboarded: true,
        );

        final Future<void> pending = cubit.decide();
        await cubit.close();
        if (succeeds) {
          answer.complete(true);
        } else {
          answer.completeError(Exception('keystore'));
        }
        await pending;

        expect(cubit.state, const StartupLoading());
        expect(observer.errors, isEmpty);
      });
    }
  });
}
