import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/models/route_progress.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/routing_repository.dart';

/// What the map says about the recording.
enum MapTrackingStatus {
  recording,
  weakSignal,

  /// No fix for a while. The route stays on the map.
  unavailable,

  /// Permission or location services went: nothing is being recorded.
  interrupted,

  /// Back after a gap; shown for a moment.
  resumed,
  completed,
}

/// A journey on the map. Everything comes from [JourneyTracker]'s existing
/// snapshots, summary and stored points. For an active journey it joins the
/// one recording as the journey screen does; it opens no location subscription
/// of its own, writes nothing, and closing it changes nothing about the
/// recording. One per screen.
class JourneyMapCubit extends Cubit<JourneyMapState> {
  JourneyMapCubit(
    this._tracker,
    this._journeys,
    this._routing, {
    this.resumedFor = const Duration(seconds: 6),
  }) : super(const JourneyMapState());

  final JourneyTracker _tracker;
  final JourneyRepository _journeys;
  final RoutingRepository _routing;

  /// How long "Tracking resumed" stays.
  final Duration resumedFor;

  StreamSubscription<TrackingSnapshot?>? _snapshots;
  StreamSubscription<void>? _changes;
  Timer? _resumed;
  String? _id;

  /// One list per unbroken stretch: no line is ever drawn across a gap.
  final List<List<LatLng>> _segments = <List<LatLng>>[];
  TrackPoint? _tail;
  TrackPoint? _beforeTail;
  int _lastSegment = -1;

  Future<void> open(String id) async {
    _id = id;
    // First, so nothing recorded while the stored points load is missed.
    _snapshots = _tracker.snapshots.listen(_onSnapshot);
    _changes = _journeys.changes.listen((_) => _reload());
    final JourneyModel? journey = await _read(id);
    if (isClosed) return;
    if (journey == null) {
      emit(state.copyWith(loading: false, missing: true));
      return;
    }
    final List<TrackPoint> stored = await _tracker.points(id);
    final RouteSummary? recorded = await _tracker.recorded(id);
    if (isClosed) return;
    final List<TrackPoint> live = _taken;
    _reset();
    stored.forEach(_add);
    live.where(_isNew).forEach(_add);
    final bool ended = journey.status != JourneyStatus.active;
    emit(
      state.copyWith(
        loading: false,
        journey: journey,
        status: ended ? MapTrackingStatus.completed : state.status,
        // A snapshot that arrived while this loaded is the newer figure.
        distanceMeters: state.distanceMeters ?? recorded?.distanceMeters,
        routeVersion: state.routeVersion + 1,
        current: _tail,
        heading: _heading(),
      ),
    );
    if (!ended) await _join(id);
    await _loadPlanned(journey);
  }

  final List<TrackPoint> _taken = <TrackPoint>[];

  /// Joins the recording as the journey screen does: never asks anything.
  Future<void> _join(String id) async {
    final TrackStart result = await _tracker.start(id);
    if (isClosed) return;
    if (result != TrackStart.recording) {
      emit(state.copyWith(status: MapTrackingStatus.interrupted));
    }
  }

  Future<void> _loadPlanned(JourneyModel journey) async {
    final JourneyPlace? from = journey.originPlace;
    final JourneyPlace? to = journey.destinationPlace;
    if (from == null || to == null) return;
    try {
      final PlannedRoute route = await _routing.route(from.point, to.point);
      if (isClosed) return;
      emit(state.copyWith(planned: route, progress: _progress(route)));
    } on MapFailure {
      // Only the preview is lost: no remaining distance is offered.
    }
  }

  void _onSnapshot(TrackingSnapshot? snapshot) {
    if (isClosed) return;
    if (snapshot == null) {
      unawaited(_reload());
      return;
    }
    if (snapshot.journeyId != _id) return;
    final TrackPoint? last = snapshot.last;
    bool moved = false;
    if (last != null && _isNew(last)) {
      if (state.loading) _taken.add(last);
      _add(last);
      moved = true;
    }
    final MapTrackingStatus status = _status(snapshot.status);
    final PlannedRoute? planned = state.planned;
    emit(
      state.copyWith(
        status: status,
        speed: snapshot.speed,
        distanceMeters: snapshot.distanceMeters,
        current: _tail,
        heading: _heading(),
        routeVersion: moved ? state.routeVersion + 1 : state.routeVersion,
        progress: moved && planned != null
            ? _progress(planned)
            : state.progress,
      ),
    );
  }

  bool _isNew(TrackPoint p) {
    final TrackPoint? tail = _tail;
    return tail == null || p.at.isAfter(tail.at);
  }

  void _add(TrackPoint p) {
    if (p.segment != _lastSegment || _segments.isEmpty) {
      _segments.add(<LatLng>[]);
      _lastSegment = p.segment;
    }
    _segments.last.add(LatLng(p.lat, p.lng));
    _beforeTail = _tail;
    _tail = p;
  }

  void _reset() {
    _segments.clear();
    _tail = null;
    _beforeTail = null;
    _lastSegment = -1;
  }

  /// The recorded route, for drawing. Never the stored data itself.
  List<List<LatLng>> get segments => _segments;

  MapTrackingStatus _status(TrackingStatus status) {
    final MapTrackingStatus next = switch (status) {
      TrackingStatus.starting ||
      TrackingStatus.active => MapTrackingStatus.recording,
      TrackingStatus.weakSignal => MapTrackingStatus.weakSignal,
      TrackingStatus.noSignal => MapTrackingStatus.unavailable,
      TrackingStatus.permissionRequired ||
      TrackingStatus.preciseOff ||
      TrackingStatus.locationOff => MapTrackingStatus.interrupted,
    };
    final bool wasLost =
        state.status == MapTrackingStatus.unavailable ||
        state.status == MapTrackingStatus.interrupted;
    if (next == MapTrackingStatus.recording && wasLost) {
      _resumed?.cancel();
      _resumed = Timer(resumedFor, _settle);
      return MapTrackingStatus.resumed;
    }
    // A fresh fix does not cut the "resumed" moment short.
    return next == MapTrackingStatus.recording && _resumed?.isActive == true
        ? MapTrackingStatus.resumed
        : next;
  }

  void _settle() {
    if (!isClosed && state.status == MapTrackingStatus.resumed) {
      emit(state.copyWith(status: MapTrackingStatus.recording));
    }
  }

  /// Which way the phone is heading: from two trusted points, and only at a
  /// speed where that means something. Standing still has no direction.
  double? _heading() {
    final TrackPoint? a = _beforeTail;
    final TrackPoint? b = _tail;
    if (a == null || b == null || a.segment != b.segment) return null;
    if ((b.speed ?? 0) < 2) return null;
    return const Distance().bearing(LatLng(a.lat, a.lng), LatLng(b.lat, b.lng));
  }

  RouteProgress? _progress(PlannedRoute route) {
    final TrackPoint? at = _tail;
    return at == null
        ? null
        : RouteProgress.along(route, LatLng(at.lat, at.lng));
  }

  /// The journey may have ended, here or on another phone.
  Future<void> _reload() async {
    final String? id = _id;
    if (id == null) return;
    final JourneyModel? journey = await _read(id);
    if (isClosed || journey == null) return;
    final bool ended = journey.status != JourneyStatus.active;
    emit(
      state.copyWith(
        journey: journey,
        status: ended ? MapTrackingStatus.completed : state.status,
      ),
    );
  }

  Future<JourneyModel?> _read(String id) async {
    try {
      return await _journeys.journey(id);
    } on JourneyFailure {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _resumed?.cancel();
    await _snapshots?.cancel();
    await _changes?.cancel();
    return super.close();
  }
}

final class JourneyMapState extends Equatable {
  const JourneyMapState({
    this.loading = true,
    this.missing = false,
    this.journey,
    this.status = MapTrackingStatus.recording,
    this.speed = const SpeedReading.unavailable(),
    this.distanceMeters,
    this.current,
    this.heading,
    this.routeVersion = 0,
    this.planned,
    this.progress,
  });

  final bool loading;
  final bool missing;
  final JourneyModel? journey;
  final MapTrackingStatus status;
  final SpeedReading speed;

  /// Null when nothing says how far it went: unknown is not zero.
  final double? distanceMeters;

  /// The latest trusted point. It stays through a signal loss.
  final TrackPoint? current;

  /// Degrees, when the direction is reliable.
  final double? heading;

  /// Moves when the recorded route does: a long list is never compared.
  final int routeVersion;
  final PlannedRoute? planned;

  /// Null unless the position can be placed on the planned route.
  final RouteProgress? progress;

  JourneyMapState copyWith({
    bool? loading,
    bool? missing,
    JourneyModel? journey,
    MapTrackingStatus? status,
    SpeedReading? speed,
    double? distanceMeters,
    TrackPoint? current,
    Object? heading = _keep,
    int? routeVersion,
    PlannedRoute? planned,
    Object? progress = _keep,
  }) => JourneyMapState(
    loading: loading ?? this.loading,
    missing: missing ?? this.missing,
    journey: journey ?? this.journey,
    status: status ?? this.status,
    speed: speed ?? this.speed,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    current: current ?? this.current,
    heading: identical(heading, _keep) ? this.heading : heading as double?,
    routeVersion: routeVersion ?? this.routeVersion,
    planned: planned ?? this.planned,
    progress: identical(progress, _keep)
        ? this.progress
        : progress as RouteProgress?,
  );

  /// Heading and progress can go back to null: "not given" must differ.
  static const Object _keep = Object();

  @override
  List<Object?> get props => <Object?>[
    loading,
    missing,
    journey,
    status,
    speed,
    distanceMeters,
    current,
    heading,
    routeVersion,
    planned,
    progress,
  ];
}
