import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';

/// The open potential incident of one journey, for its screen — movement
/// only (a tracking interruption is already shown by the recording card's
/// status), and only medium or high confidence: a low one (a firm brake
/// before a red light can make one) is kept for the record, not shown.
/// Follows the stored events as they change. One per screen.
class IncidentCubit extends Cubit<IncidentState> {
  IncidentCubit(this._repository, this._session)
    : super(const IncidentState(null)) {
    _changes = _repository.changes.listen((_) => _load());
  }

  final IncidentRepository _repository;
  final SessionReader _session;
  late final StreamSubscription<void> _changes;
  String? _journeyId;

  Future<void> watch(String journeyId) {
    _journeyId = journeyId;
    return _load();
  }

  /// The user says they are fine: the event is closed as dismissed.
  Future<void> dismiss() async {
    final PotentialIncident? open = state.incident;
    if (open == null) return;
    await _repository.put(
      open.copyWith(
        status: IncidentStatus.dismissed,
        resolution: IncidentResolution.dismissedByUser,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _load() async {
    final String? journeyId = _journeyId;
    final String? uid = (await _session.signedInUser())?.id;
    if (journeyId == null || uid == null) return;
    PotentialIncident? open;
    for (final PotentialIncident i in await _repository.forJourney(
      uid,
      journeyId,
    )) {
      if (i.status == IncidentStatus.detected &&
          i.type != IncidentType.trackingInterrupted &&
          i.confidence != IncidentConfidence.low) {
        open = i;
      }
    }
    if (!isClosed) emit(IncidentState(open));
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}

/// [incident] is the journey's open movement event, if any.
final class IncidentState extends Equatable {
  const IncidentState(this.incident);

  final PotentialIncident? incident;

  @override
  List<Object?> get props => <Object?>[incident];
}
