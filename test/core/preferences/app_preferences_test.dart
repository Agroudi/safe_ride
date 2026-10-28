import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fresh install, or one whose store already holds [stored].
Future<AppPreferences> _install([
  Map<String, Object> stored = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  return AppPreferences(await SharedPreferences.getInstance());
}

/// The store as the next launch finds it: drops the cached instance and reads
/// the mocked platform store again, so only what was actually written survives.
Future<SharedPreferences> _storeAfterRestart() {
  SharedPreferences.resetStatic();
  return SharedPreferences.getInstance();
}

/// The next launch.
Future<AppPreferences> _restart() async =>
    AppPreferences(await _storeAfterRestart());

void main() {
  group('defaults on a fresh install', () {
    test('onboarding is not completed', () async {
      final AppPreferences preferences = await _install();

      expect(preferences.onboardingCompleted, isFalse);
    });

    test('the theme follows the system', () async {
      final AppPreferences preferences = await _install();

      expect(preferences.themeMode, ThemeMode.system);
    });
  });

  group('onboarding flag', () {
    test('reads back true once set, and survives a restart', () async {
      final AppPreferences preferences = await _install();

      await preferences.setOnboardingCompleted();

      expect(preferences.onboardingCompleted, isTrue);
      expect((await _restart()).onboardingCompleted, isTrue);
    });

    // The key is the storage format: renaming it would show onboarding again
    // to everyone who already finished it.
    test('is stored as a bool under prefs.onboardingCompleted', () async {
      await (await _install()).setOnboardingCompleted();

      final SharedPreferences raw = await _storeAfterRestart();
      expect(raw.getBool('prefs.onboardingCompleted'), isTrue);
    });

    test('reads a value already in the store', () async {
      final AppPreferences preferences = await _install(<String, Object>{
        'prefs.onboardingCompleted': true,
      });

      expect(preferences.onboardingCompleted, isTrue);
    });
  });

  group('theme mode', () {
    for (final ThemeMode mode in ThemeMode.values) {
      test('${mode.name} reads back, and survives a restart', () async {
        final AppPreferences preferences = await _install();

        await preferences.setThemeMode(mode);

        expect(preferences.themeMode, mode);
        expect((await _restart()).themeMode, mode);
      });
    }

    // Same reason as the onboarding key: the stored name is the format.
    test('is stored as ThemeMode.name under prefs.themeMode', () async {
      await (await _install()).setThemeMode(ThemeMode.dark);

      final SharedPreferences raw = await _storeAfterRestart();
      expect(raw.getString('prefs.themeMode'), 'dark');
    });

    test('the last choice wins', () async {
      final AppPreferences preferences = await _install();

      await preferences.setThemeMode(ThemeMode.dark);
      await preferences.setThemeMode(ThemeMode.light);

      expect((await _restart()).themeMode, ThemeMode.light);
    });

    // A value from a future version or a hand-edited file must not crash the
    // first frame or pick a theme nobody chose.
    for (final String unknown in <String>['sepia', 'Dark', '']) {
      test('unknown stored value "$unknown" falls back to system', () async {
        final AppPreferences preferences = await _install(<String, Object>{
          'prefs.themeMode': unknown,
        });

        expect(preferences.themeMode, ThemeMode.system);
      });
    }
  });

  // Read on the way to the first frame: a value of the wrong type must read
  // as missing, never throw.
  group('a stored value of the wrong type', () {
    test('theme mode stored as an int falls back to system', () async {
      final AppPreferences preferences = await _install(<String, Object>{
        'prefs.themeMode': 2,
      });

      expect(preferences.themeMode, ThemeMode.system);
    });

    for (final Object wrong in <Object>['true', 1]) {
      test('onboarding flag stored as ${wrong.runtimeType} "$wrong" is '
          'not completed', () async {
        final AppPreferences preferences = await _install(<String, Object>{
          'prefs.onboardingCompleted': wrong,
        });

        expect(preferences.onboardingCompleted, isFalse);
      });
    }

    test('is overwritten by the next choice', () async {
      final AppPreferences preferences = await _install(<String, Object>{
        'prefs.themeMode': 2,
        'prefs.onboardingCompleted': 'true',
      });

      await preferences.setThemeMode(ThemeMode.dark);
      await preferences.setOnboardingCompleted();

      final AppPreferences next = await _restart();
      expect(next.themeMode, ThemeMode.dark);
      expect(next.onboardingCompleted, isTrue);
    });
  });
}
