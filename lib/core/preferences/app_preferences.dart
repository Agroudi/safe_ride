import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The small, non-secret settings the app keeps between launches: whether
/// onboarding was finished, the chosen theme, this install's id, and the
/// country the user says they are in (with whether the account has it yet).
///
/// The language is **not** here — easy_localization saves it on its own
/// (`context.setLocale` persists), and a second copy would drift from it.
/// Secrets never go here either: the session is Firebase's own.
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
  static const String _installIdKey = 'prefs.installId';
  static const String _countryKey = 'prefs.country';
  static const String _countryUidKey = 'prefs.countryUid';
  static const String _countryPendingKey = 'prefs.countryPending';

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

  /// The country chosen on this phone (ISO code), the account it was last
  /// matched with, and whether that account still has to receive it. Kept
  /// here so the emergency numbers never wait on the network.
  ({String? code, String? uid, bool pending}) get country {
    final Object? code = _prefs.get(_countryKey);
    final Object? uid = _prefs.get(_countryUidKey);
    return (
      code: code is String ? code : null,
      uid: uid is String ? uid : null,
      pending: _prefs.get(_countryPendingKey) == true,
    );
  }

  Future<void> setCountry(String code, {String? uid, required bool pending}) =>
      Future.wait(<Future<bool>>[
        _prefs.setString(_countryKey, code),
        if (uid == null)
          _prefs.remove(_countryUidKey)
        else
          _prefs.setString(_countryUidKey, uid),
        _prefs.setBool(_countryPendingKey, pending),
      ]);

  Future<void> clearCountry() => Future.wait(<Future<bool>>[
    _prefs.remove(_countryKey),
    _prefs.remove(_countryUidKey),
    _prefs.remove(_countryPendingKey),
  ]);

  /// A random id for this install, made on first use and kept: the document
  /// id of its push token (`users/{uid}/devices/{id}`), so a token refresh
  /// replaces its own record instead of adding one. It names nothing about
  /// the person or the phone.
  Future<String> installId() async {
    final Object? stored = _prefs.get(_installIdKey);
    if (stored is String && stored.isNotEmpty) return stored;
    final Random random = Random.secure();
    final String id = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _prefs.setString(_installIdKey, id);
    return id;
  }
}
