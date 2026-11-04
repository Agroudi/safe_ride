import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/country/country_repository.dart';

/// The country the user is in, for one screen: this phone's copy at once,
/// then agreed with the account in the background. One per screen.
class CountryCubit extends Cubit<CountryState> {
  CountryCubit(this._repository) : super(CountryState(_repository.current())) {
    _changes = _repository.changes.listen(
      (_) => emit(CountryState(_repository.current())),
    );
    unawaited(_repository.reconcile());
  }

  final CountryRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> choose(String code) => _repository.choose(code);

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}

/// [country] is null until the user chooses one.
final class CountryState extends Equatable {
  const CountryState(this.country);

  final Country? country;

  @override
  List<Object?> get props => <Object?>[country];
}
