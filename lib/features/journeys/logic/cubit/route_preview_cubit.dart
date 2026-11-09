import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/routing_repository.dart';

/// The route between the two chosen places. Asked for only when a place
/// changes. A failure is only that: the places stay, and the journey can
/// still be planned. One per screen.
class RoutePreviewCubit extends Cubit<RoutePreviewState> {
  RoutePreviewCubit(this._routing) : super(const RoutePreviewState());

  final RoutingRepository _routing;
  LatLng? _from;
  LatLng? _to;
  int _asked = 0;

  Future<void> update(LatLng? from, LatLng? to) async {
    if (from == _from && to == _to && state.route != null) return;
    _from = from;
    _to = to;
    final int mine = ++_asked;
    if (from == null || to == null) {
      emit(const RoutePreviewState());
      return;
    }
    emit(const RoutePreviewState(loading: true));
    try {
      final PlannedRoute route = await _routing.route(from, to);
      if (!isClosed && mine == _asked) emit(RoutePreviewState(route: route));
    } on MapFailure catch (e) {
      if (!isClosed && mine == _asked) emit(RoutePreviewState(failure: e.code));
    }
  }

  Future<void> retry() => update(_from, _to);
}

final class RoutePreviewState extends Equatable {
  const RoutePreviewState({this.route, this.loading = false, this.failure});

  final PlannedRoute? route;
  final bool loading;
  final MapFailureCode? failure;

  @override
  List<Object?> get props => <Object?>[route, loading, failure];
}
