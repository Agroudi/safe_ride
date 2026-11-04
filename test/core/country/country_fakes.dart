import 'dart:async';

import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/country/country_repository.dart';

/// [CountryRepository] in memory: the country is whatever the test sets.
class MemoryCountryRepository implements CountryRepository {
  MemoryCountryRepository([this.code]);

  String? code;
  int reconciled = 0;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Country? current() => Countries.byCode(code);

  @override
  Future<void> choose(String code) async {
    this.code = code;
    _changes.add(null);
  }

  @override
  Future<void> reconcile() async => reconciled++;
}
