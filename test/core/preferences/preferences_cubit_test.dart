import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/preferences/preferences_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A cubit over a fresh install, or one whose store already holds [stored].
Future<PreferencesCubit> _launch([
  Map<String, Object> stored = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  return _open();
}

/// The next launch over the same mocked store: a new [AppPreferences] and a
/// new cubit, with nothing carried over from the previous ones in memory.
Future<PreferencesCubit> _relaunch() {
  SharedPreferences.resetStatic();
  return _open();
}

/// The store as the next launch reads it — not the in-memory copy.
Future<SharedPreferences> _reloaded() {
  SharedPreferences.resetStatic();
  return SharedPreferences.getInstance();
}

Future<PreferencesCubit> _open() async {
  final PreferencesCubit cubit = PreferencesCubit(
    AppPreferences(await SharedPreferences.getInstance()),
  );
  addTearDown(cubit.close);
  return cubit;
}

/// Runs [action] and returns every state the cubit emitted while it did.
Future<List<PreferencesState>> _emitted(
  PreferencesCubit cubit,
  Future<void> Function() action,
) async {
  final List<PreferencesState> states = <PreferencesState>[];
  final StreamSubscription<PreferencesState> subscription = cubit.stream.listen(
    states.add,
  );
  await action();
  // The state stream is asynchronous: let it deliver before reading.
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  return states;
}

void main() {
  group('initial state', () {
    test('a fresh install follows the system', () async {
      final PreferencesCubit cubit = await _launch();

      expect(cubit.state, const PreferencesState(themeMode: ThemeMode.system));
    });

    // Read synchronously in the constructor: the first frame already paints
    // the saved theme.
    test('reflects what the previous launch stored', () async {
      final PreferencesCubit cubit = await _launch(<String, Object>{
        'prefs.themeMode': 'dark',
      });

      expect(cubit.state, const PreferencesState(themeMode: ThemeMode.dark));
    });
  });

  group('setThemeMode', () {
    test('emits the new mode and persists it across a restart', () async {
      final PreferencesCubit cubit = await _launch();

      final List<PreferencesState> states = await _emitted(
        cubit,
        () => cubit.setThemeMode(ThemeMode.dark),
      );

      expect(states, const <PreferencesState>[
        PreferencesState(themeMode: ThemeMode.dark),
      ]);
      expect((await _relaunch()).state.themeMode, ThemeMode.dark);
    });

    // Emit first: the switch must not wait on a disk write.
    test('the new mode is the state before the write finishes', () async {
      final PreferencesCubit cubit = await _launch();

      final Future<void> pending = cubit.setThemeMode(ThemeMode.light);

      expect(cubit.state.themeMode, ThemeMode.light);
      await pending;
    });

    test('keeps the onboarding flag', () async {
      final PreferencesCubit cubit = await _launch(<String, Object>{
        'prefs.onboardingCompleted': true,
      });

      await cubit.setThemeMode(ThemeMode.light);

      expect(AppPreferences(await _reloaded()).onboardingCompleted, isTrue);
    });

    test('the same mode emits nothing and writes nothing', () async {
      final PreferencesCubit cubit = await _launch();

      final List<PreferencesState> states = await _emitted(
        cubit,
        () => cubit.setThemeMode(ThemeMode.system),
      );

      expect(states, isEmpty);
      final SharedPreferences raw = await SharedPreferences.getInstance();
      expect(raw.containsKey('prefs.themeMode'), isFalse);
    });
  });

  group('completeOnboarding', () {
    // Nothing on screen redraws for the flag, so nothing is emitted: the
    // write is the whole job, and the next launch is what reads it.
    test('persists the flag across a restart and emits nothing', () async {
      final PreferencesCubit cubit = await _launch();

      final List<PreferencesState> states = await _emitted(
        cubit,
        cubit.completeOnboarding,
      );

      expect(states, isEmpty);
      expect(AppPreferences(await _reloaded()).onboardingCompleted, isTrue);
    });

    test('keeps the theme mode', () async {
      final PreferencesCubit cubit = await _launch(<String, Object>{
        'prefs.themeMode': 'dark',
      });

      await cubit.completeOnboarding();

      expect(cubit.state.themeMode, ThemeMode.dark);
    });
  });
}
