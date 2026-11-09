import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

/// What someone might want through a connection.
enum ConnectionAccessKind {
  liveLocation,
  journeyHistory,
  gpsHistory,
  emergencyInformation,
  safetyAlerts,
}

/// The one answer to "does this connection allow that?", for every later
/// feature that asks. A connection opens nothing about the account: location
/// and journeys are refused whatever is stored, and they are shared only by a
/// link the user makes (`docs/connections.md`). Nothing in `firestore.rules`
/// reads a connection, so this cannot be widened from the phone.
abstract final class ConnectionAccess {
  static bool allows(
    ConnectionModel connection,
    ConnectionAccessKind what, {
    bool alertsBackend = AppFeatures.contactAlerts,
  }) => switch (what) {
    ConnectionAccessKind.liveLocation ||
    ConnectionAccessKind.journeyHistory ||
    ConnectionAccessKind.gpsHistory ||
    ConnectionAccessKind.emergencyInformation => false,
    ConnectionAccessKind.safetyAlerts =>
      connection.isActive &&
          connection.permissions.safetyAlerts &&
          alertsBackend,
  };
}
