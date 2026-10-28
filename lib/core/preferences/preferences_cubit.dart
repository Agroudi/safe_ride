import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_state.dart';

/// Holds the theme mode for the whole app, and writes the onboarding flag.
///
/// ⚠️ An app-level **lazy singleton**, provided above `MaterialApp` — the one
/// documented exception to "cubits are factories". The theme is app state, not
/// screen state: a per-screen copy would disagree with the one painting the app.
class PreferencesCubit extends Cubit<PreferencesState> {
  /// The initial state is read synchronously, so the first frame is already in
  /// the saved theme — no light flash before a dark app.
  PreferencesCubit(this._preferences)
    : super(PreferencesState(themeMode: _preferences.themeMode));

  final AppPreferences _preferences;

  /// Emits first so the switch is instant, then persists. A failed write only
  /// costs the choice on the next launch.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state.themeMode) return;
    emit(state.copyWith(themeMode: mode));
    await _preferences.setThemeMode(mode);
  }

  /// Persists only — no state changes. The caller awaits it before leaving
  /// onboarding: a flag that was never written would show onboarding again
  /// on the next launch.
  Future<void> completeOnboarding() => _preferences.setOnboardingCompleted();
}
