import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// The app-wide settings the UI reacts to. One value class, not a sealed
/// family: preferences are never "loading" — they are read before the first
/// frame.
///
/// The onboarding flag is not here: nothing redraws when it changes, and the
/// one reader (`StartupCubit`) asks `AppPreferences` — a second copy in state
/// could only drift from it.
final class PreferencesState extends Equatable {
  const PreferencesState({required this.themeMode});

  final ThemeMode themeMode;

  PreferencesState copyWith({ThemeMode? themeMode}) {
    return PreferencesState(themeMode: themeMode ?? this.themeMode);
  }

  @override
  List<Object?> get props => <Object?>[themeMode];
}
