import 'package:equatable/equatable.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';

/// The emergency numbers screen.
sealed class EmergencyState extends Equatable {
  const EmergencyState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class EmergencyLoading extends EmergencyState {
  const EmergencyLoading();
}

/// No country chosen yet: SafeRide does not guess it.
final class EmergencyNeedsCountry extends EmergencyState {
  const EmergencyNeedsCountry();
}

/// [country]'s checked numbers.
final class EmergencyReady extends EmergencyState {
  const EmergencyReady(this.country, this.numbers);

  final Country country;
  final EmergencyCountry numbers;

  @override
  List<Object?> get props => <Object?>[country, numbers];
}

/// A country with no checked numbers in the dataset (or an entry that failed
/// its checks): nothing is shown rather than something unverified.
final class EmergencyUnavailable extends EmergencyState {
  const EmergencyUnavailable(this.country);

  final Country country;

  @override
  List<Object?> get props => <Object?>[country];
}
