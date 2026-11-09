import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/security/bearer_token.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/data/repository/shared_view_repository.dart';

enum SharedViewPhase {
  loading,

  /// Something to show. [SharedViewState.liveness] says how far to trust it.
  ready,

  /// Stopped, expired, or never a share: the three look alike on purpose.
  ended,

  /// Nothing yet, and the server cannot be reached.
  unreachable,
}

final class SharedViewState extends Equatable {
  const SharedViewState({
    this.phase = SharedViewPhase.loading,
    this.view,
    this.liveness = SharedLiveness.waiting,
    this.offline = false,
    this.routeVersion = 0,
  });

  final SharedViewPhase phase;
  final SharedView? view;
  final SharedLiveness liveness;
  final bool offline;

  /// Moves when the route does: a long list is never compared.
  final int routeVersion;

  SharedViewState copyWith({
    SharedViewPhase? phase,
    SharedView? view,
    SharedLiveness? liveness,
    bool? offline,
    int? routeVersion,
  }) => SharedViewState(
    phase: phase ?? this.phase,
    view: view ?? this.view,
    liveness: liveness ?? this.liveness,
    offline: offline ?? this.offline,
    routeVersion: routeVersion ?? this.routeVersion,
  );

  @override
  List<Object?> get props => <Object?>[
    phase,
    view,
    liveness,
    offline,
    routeVersion,
  ];
}

/// A recipient's view of one link: read-only, with no account. It re-judges
/// the position every few seconds, so an old one stops being called live with
/// nothing arriving to say so. One per screen.
class SharedViewCubit extends Cubit<SharedViewState> {
  SharedViewCubit(
    this._repository, {
    DateTime Function()? clock,
    this.checkEvery = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now,
       super(const SharedViewState());

  final SharedViewRepository _repository;
  final DateTime Function() _clock;
  final Duration checkEvery;

  StreamSubscription<SharedViewEvent>? _events;
  Timer? _checks;
  String? _token;
  DateTime _heardAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final Map<int, List<SharedRoutePoint>> _chunks =
      <int, List<SharedRoutePoint>>{};
  int _routeLoaded = -1;

  /// The route, for drawing: no line crosses a gap in the recording.
  List<List<LatLng>> get segments =>
      SharedRoutePoint.segments(<SharedRoutePoint>[
        for (final int c in _chunks.keys.toList()..sort()) ..._chunks[c]!,
      ]);

  void open(String? token) {
    if (!BearerToken.isValid(token)) {
      emit(const SharedViewState(phase: SharedViewPhase.ended));
      return;
    }
    _token = token;
    _events = _repository.watch(token!).listen(_onEvent);
    _checks = Timer.periodic(checkEvery, (_) => check());
  }

  void _onEvent(SharedViewEvent event) {
    if (isClosed) return;
    if (event.ended) {
      _end();
      return;
    }
    final SharedView? view = event.view ?? state.view;
    if (view == null) {
      emit(state.copyWith(phase: SharedViewPhase.unreachable, offline: true));
      return;
    }
    if (!event.offline) _heardAt = _clock().toUtc();
    emit(state.copyWith(view: view, offline: event.offline));
    check();
    if (view.routeVersion != _routeLoaded) unawaited(_loadRoute(view));
  }

  /// Judges what is shown again, as time passes.
  void check() {
    final SharedView? view = state.view;
    if (isClosed || view == null) return;
    final DateTime now = _clock().toUtc();
    if (view.expiredAt(now)) {
      _end();
      return;
    }
    emit(
      state.copyWith(
        phase: SharedViewPhase.ready,
        liveness: view.liveness(
          now: now,
          heardAt: _heardAt,
          offline: state.offline,
        ),
      ),
    );
  }

  void _end() {
    _checks?.cancel();
    unawaited(_events?.cancel());
    // What was seen stays seen, but this screen no longer shows it.
    _chunks.clear();
    emit(const SharedViewState(phase: SharedViewPhase.ended));
  }

  /// Only the chunks that can have changed: the last one kept, and any newer.
  Future<void> _loadRoute(SharedView view) async {
    final String? token = _token;
    if (token == null) return;
    _routeLoaded = view.routeVersion;
    final int from = _chunks.isEmpty ? 0 : (_chunks.keys.last);
    for (int c = from; c < view.routeChunks; c++) {
      final List<SharedRoutePoint> points = await _repository.chunk(token, c);
      if (isClosed) return;
      if (points.isNotEmpty) _chunks[c] = points;
    }
    if (state.phase != SharedViewPhase.ended) {
      emit(state.copyWith(routeVersion: state.routeVersion + 1));
    }
  }

  @override
  Future<void> close() async {
    _checks?.cancel();
    await _events?.cancel();
    return super.close();
  }
}
