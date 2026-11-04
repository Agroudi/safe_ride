import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';

/// What the phone's preferences hold for one account: the country chosen for
/// it. Language, theme and the onboarding flag belong to the phone, not the
/// account, and stay.
class PreferencesAccountData implements AccountData {
  const PreferencesAccountData(this._preferences);

  final AppPreferences _preferences;

  @override
  Future<void> erase(String uid) async {
    if (_preferences.country.uid == uid) await _preferences.clearCountry();
  }
}
