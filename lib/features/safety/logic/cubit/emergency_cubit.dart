import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/country/country_repository.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_state.dart';

/// The emergency numbers for the country the user says they are in. Reads
/// only this phone (the chosen country, the bundled numbers), so it works
/// offline; follows a change of country from anywhere. One per screen.
class EmergencyCubit extends Cubit<EmergencyState> {
  EmergencyCubit(this._countries, this._numbers, this._dialer)
    : super(const EmergencyLoading()) {
    _changes = _countries.changes.listen((_) => load());
  }

  final CountryRepository _countries;
  final EmergencyRepository _numbers;
  final PhoneDialer _dialer;
  late final StreamSubscription<void> _changes;

  Future<void> load() async {
    final Country? country = _countries.current();
    if (country == null) {
      if (!isClosed) emit(const EmergencyNeedsCountry());
      // A new phone: the account may know the country.
      unawaited(_countries.reconcile());
      return;
    }
    final EmergencyCountry? numbers = await _numbers.forCountry(country.code);
    if (isClosed) return;
    emit(
      numbers == null
          ? EmergencyUnavailable(country)
          : EmergencyReady(country, numbers),
    );
  }

  Future<void> choose(String code) => _countries.choose(code);

  /// Opens the phone app with [number]; the outcome says only that.
  Future<DialOutcome> dial(String number) => _dialer.open(number);

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
