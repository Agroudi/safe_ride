import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';

/// The emergency numbers by country — the one place the screens ask.
/// `BundledEmergencyRepository` implements it over the app's own dataset;
/// a remotely updated dataset would be another implementation.
abstract interface class EmergencyRepository {
  /// [code]'s numbers, or null when SafeRide has no checked numbers for it.
  Future<EmergencyCountry?> forCountry(String code);
}

/// [EmergencyRepository] over [EmergencyDataSource], read once and kept.
class BundledEmergencyRepository implements EmergencyRepository {
  BundledEmergencyRepository(this._source);

  final EmergencyDataSource _source;
  Future<Map<String, EmergencyCountry>>? _loaded;

  @override
  Future<EmergencyCountry?> forCountry(String code) async =>
      (await (_loaded ??= _source.load()))[code];
}
