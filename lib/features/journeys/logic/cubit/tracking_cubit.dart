import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/logic/states/tracking_state.dart';

/// One journey screen's view of [JourneyTracker]: for a journey in
/// progress it starts (or joins) the recording when location is allowed,
/// and asks for it only when the user taps; for an ended journey it shows
/// what was recorded. One per screen.
class TrackingCubit extends Cubit<TrackingState> {
  TrackingCubit(this._tracker) : super(const TrackingIdle()) {
    _snapshots = _tracker.snapshots.listen(_onSnapshot);
  }

  final JourneyTracker _tracker;
  late final StreamSubscription<TrackingSnapshot?> _snapshots;
  JourneyModel? _journey;

  /// Shows [journey]'s recording — again whenever its status changes.
  Future<void> watch(JourneyModel journey) async {
    _journey = journey;
    switch (journey.status) {
      case JourneyStatus.active:
        await _begin();
      case JourneyStatus.completed || JourneyStatus.cancelled:
        final RouteSummary? summary = await _tracker.recorded(journey.id);
        if (!isClosed && _journey == journey) emit(TrackingRecorded(summary));
      case JourneyStatus.planned:
        emit(const TrackingIdle());
    }
  }

  /// Back from the system settings, or the app resumed: try again.
  Future<void> refresh() async {
    if (_journey?.status == JourneyStatus.active) await _begin();
  }

  /// The user's tap: shows the system prompt when the system still allows
  /// one, then records if it was granted.
  Future<void> allow() async {
    final LocationAccess access = await _tracker.requestAccess();
    if (access == LocationAccess.granted) {
      await _begin();
    } else if (!isClosed) {
      emit(TrackingNeedsAccess(access));
    }
  }

  /// Where the user can fix [access] themselves.
  Future<void> openSettings(LocationAccess access) =>
      access == LocationAccess.serviceOff
      ? _tracker.openLocationSettings()
      : _tracker.openAppSettings();

  Future<void> _begin() async {
    final JourneyModel? journey = _journey;
    if (journey == null) return;
    final TrackStart result;
    try {
      result = await _tracker.start(journey.id);
    } on Object {
      if (!isClosed) emit(const TrackingFailed());
      return;
    }
    if (isClosed) return;
    switch (result) {
      case TrackStart.recording:
        final TrackingSnapshot? now = _tracker.current;
        if (now != null) emit(TrackingLive(now));
      case TrackStart.noAccess:
        final LocationAccess access = await _tracker.access();
        if (!isClosed) emit(TrackingNeedsAccess(access));
      case TrackStart.otherJourney:
        emit(const TrackingElsewhere());
      case TrackStart.notActive:
        // This screen shows the journey in progress: "not active" here means
        // it could not be confirmed, and silence would read as recording.
        emit(
          _journey?.status == JourneyStatus.active
              ? const TrackingFailed()
              : const TrackingIdle(),
        );
      case TrackStart.signedOut:
        emit(const TrackingIdle());
    }
  }

  /// Live figures only while the journey is in progress here — the last
  /// ones a stopping recording sends must not cover what it recorded. When
  /// the recording ends, look again (an ended journey shows its summary).
  void _onSnapshot(TrackingSnapshot? snapshot) {
    final JourneyModel? journey = _journey;
    if (isClosed || journey == null) return;
    if (snapshot == null) {
      if (state is TrackingLive) unawaited(watch(journey));
    } else if (snapshot.journeyId == journey.id &&
        journey.status == JourneyStatus.active) {
      emit(TrackingLive(snapshot));
    }
  }

  @override
  Future<void> close() async {
    await _snapshots.cancel();
    return super.close();
  }
}
