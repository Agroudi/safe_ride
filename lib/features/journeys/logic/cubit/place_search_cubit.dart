import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/geocoding_repository.dart';

enum PlaceSearchStatus { idle, searching, results, empty, failed }

/// Search as you type, gently: nothing under [minLength] characters, one
/// request after typing pauses for [debounce], and a newer query aborts the
/// older one. The public geocoder's fair use depends on this. One per screen.
class PlaceSearchCubit extends Cubit<PlaceSearchState> {
  PlaceSearchCubit(
    this._geocoding, {
    this.debounce = const Duration(milliseconds: 500),
  }) : super(const PlaceSearchState(PlaceSearchStatus.idle));

  static const int minLength = 3;

  final GeocodingRepository _geocoding;
  final Duration debounce;
  Timer? _waiting;
  Completer<void>? _running;

  void query(String text, {required String languageCode, LatLng? near}) {
    _stop();
    final String q = text.trim();
    if (q.length < minLength) {
      emit(const PlaceSearchState(PlaceSearchStatus.idle));
      return;
    }
    emit(const PlaceSearchState(PlaceSearchStatus.searching));
    _waiting = Timer(debounce, () => _run(q, languageCode, near));
  }

  void clear() {
    _stop();
    emit(const PlaceSearchState(PlaceSearchStatus.idle));
  }

  void _stop() {
    _waiting?.cancel();
    final Completer<void>? running = _running;
    if (running != null && !running.isCompleted) running.complete();
    _running = null;
  }

  Future<void> _run(String q, String languageCode, LatLng? near) async {
    final Completer<void> mine = _running = Completer<void>();
    try {
      final List<JourneyPlace> places = await _geocoding.search(
        q,
        languageCode: languageCode,
        near: near,
        cancel: mine.future,
      );
      if (isClosed || !identical(_running, mine)) return;
      emit(
        PlaceSearchState(
          places.isEmpty ? PlaceSearchStatus.empty : PlaceSearchStatus.results,
          places: places,
        ),
      );
    } on MapFailure catch (e) {
      if (isClosed || !identical(_running, mine)) return;
      if (e.code == MapFailureCode.cancelled) return;
      emit(PlaceSearchState(PlaceSearchStatus.failed, failure: e.code));
    }
  }

  @override
  Future<void> close() {
    _stop();
    return super.close();
  }
}

final class PlaceSearchState extends Equatable {
  const PlaceSearchState(
    this.status, {
    this.places = const <JourneyPlace>[],
    this.failure,
  });

  final PlaceSearchStatus status;
  final List<JourneyPlace> places;
  final MapFailureCode? failure;

  @override
  List<Object?> get props => <Object?>[status, places, failure];
}
