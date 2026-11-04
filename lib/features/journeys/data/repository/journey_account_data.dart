import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/data/repository/track_store.dart';

/// What this phone holds for an account's journeys. Stops the recording and
/// any running safety check first, or they would write their files straight
/// back.
class JourneyAccountData implements AccountData {
  const JourneyAccountData({
    required JourneyTracker tracker,
    required SafetyCheckService safetyChecks,
    required TrackStore store,
    required IncidentRepository incidents,
    required SafetyCheckRepository checks,
  }) : _tracker = tracker,
       _safetyChecks = safetyChecks,
       _store = store,
       _incidents = incidents,
       _checks = checks;

  final JourneyTracker _tracker;
  final SafetyCheckService _safetyChecks;
  final TrackStore _store;
  final IncidentRepository _incidents;
  final SafetyCheckRepository _checks;

  @override
  Future<void> erase(String uid) async {
    await _tracker.discard();
    await _safetyChecks.forget();
    await _store.eraseAccount(uid);
    await _incidents.eraseAccount(uid);
    await _checks.eraseAccount(uid);
  }
}
