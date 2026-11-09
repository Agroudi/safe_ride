import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';

/// Where the user is, as a test says: no GPS, and nothing can be sent — the
/// interface has nothing that sends.
class FakePositionReader implements EmergencyPositionReader {
  FakePositionReader({
    this.known = const EmergencyPosition(access: PositionAccess.allowed),
    EmergencyPosition? located,
  }) : located = located ?? known;

  EmergencyPosition known;
  EmergencyPosition located;

  /// How many new readings were taken.
  int readings = 0;

  @override
  Future<EmergencyPosition> lastKnown() async => known;

  @override
  Future<EmergencyPosition> locateNow() async {
    readings++;
    return located;
  }
}

/// A location cubit over [reader] with no clock running: a test pumps
/// without a periodic timer left behind.
EmergencyLocationCubit stillLocationCubit(
  EmergencyPositionReader reader, {
  DateTime Function()? clock,
}) => EmergencyLocationCubit(reader, clock: clock, tick: null);
