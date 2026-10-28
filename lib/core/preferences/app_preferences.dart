import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The small, non-secret settings the app keeps between launches: whether
/// onboarding was finished, and the chosen theme.
///
/// The language is **not** here — easy_localization saves it on its own
/// (`context.setLocale` persists), and a second copy would drift from it.
/// Secrets never go here either: sessions live in secure storage.
///
/// Uses the legacy `SharedPreferences` API on purpose: it is what
/// easy_localization uses, it reads synchronously once loaded (so the first
/// frame already has the right theme), and it has `setMockInitialValues` for
/// tests.
class AppPreferences {
  const AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _onboardingCompletedKey = 'prefs.onboardingCompleted';
  static const String _themeModeKey = 'prefs.themeMode';

  // ⚠️ Both getters read untyped with `get`, not `getBool` / `getString`:
  // those cast, so a value of the wrong type (a bug that wrote one, a
  // hand-edited file) would throw from the `PreferencesCubit` constructor and
  // crash the first frame. A wrong type reads as missing instead.

  /// Anything but a stored `true` — missing, or the wrong type — is "not yet".
  bool get onboardingCompleted => _prefs.get(_onboardingCompletedKey) == true;

  Future<void> setOnboardingCompleted() =>
      _prefs.setBool(_onboardingCompletedKey, true);

  /// Stored as `ThemeMode.name`. Missing or unknown (a value from a future
  /// version, a hand-edited file, the wrong type) falls back to following the
  /// system.
  ThemeMode get themeMode {
    final Object? stored = _prefs.get(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (ThemeMode mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);
}
