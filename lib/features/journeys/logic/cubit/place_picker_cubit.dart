import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/geocoding_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';

/// The place being chosen on the map: where the pin is and what it is
/// called. The pin works without a name: naming is a courtesy from a provider
/// that may be away, and offline a pin is still a pin. One per screen.
class PlacePickerCubit extends Cubit<PlacePickerState> {
  PlacePickerCubit(
    this._geocoding,
    this._tracker, {
    this.settle = const Duration(milliseconds: 800),
  }) : super(const PlacePickerState());

  final GeocodingRepository _geocoding;
  final JourneyTracker _tracker;

  /// A pin must rest this long before anyone is asked its name.
  final Duration settle;
  Timer? _resting;
  int _asked = 0;

  /// Starts from a place already chosen.
  void start(JourneyPlace? place) {
    if (place != null) emit(PlacePickerState(point: place.point, place: place));
  }

  /// The user moved the pin.
  void moved(LatLng point, {required String languageCode}) {
    if (!JourneyPlace.validCoordinates(point.latitude, point.longitude)) return;
    _resting?.cancel();
    final int mine = ++_asked;
    emit(PlacePickerState(point: point, naming: true));
    _resting = Timer(settle, () => _name(point, languageCode, mine));
  }

  /// A search result: its name is already known.
  void picked(JourneyPlace place) {
    _resting?.cancel();
    _asked++;
    emit(PlacePickerState(point: place.point, place: place));
  }

  Future<void> _name(LatLng point, String languageCode, int mine) async {
    JourneyPlace? named;
    try {
      named = await _geocoding.reverse(point, languageCode: languageCode);
    } on MapFailure {
      named = null;
    }
    if (isClosed || mine != _asked) return;
    emit(
      PlacePickerState(
        point: point,
        // The pin stays where the user put it, whatever the provider matched.
        place: named?.copyWith(lat: point.latitude, lng: point.longitude),
      ),
    );
  }

  /// "Use my location": asks for the permission here, on the user's tap.
  Future<void> locate({required String languageCode}) async {
    emit(
      PlacePickerState(point: state.point, place: state.place, locating: true),
    );
    LocationAccess access = await _tracker.access();
    if (access != LocationAccess.granted) {
      access = await _tracker.requestAccess();
    }
    if (isClosed) return;
    if (access != LocationAccess.granted) {
      emit(
        PlacePickerState(
          point: state.point,
          place: state.place,
          locationProblem: access,
        ),
      );
      return;
    }
    final LocationFix? fix = await _tracker.locate();
    if (isClosed) return;
    if (fix == null) {
      emit(
        PlacePickerState(
          point: state.point,
          place: state.place,
          locationProblem: LocationAccess.serviceOff,
        ),
      );
      return;
    }
    moved(LatLng(fix.latitude, fix.longitude), languageCode: languageCode);
  }

  Future<void> openSettings(LocationAccess access) =>
      access == LocationAccess.serviceOff
      ? _tracker.openLocationSettings()
      : _tracker.openAppSettings();

  @override
  Future<void> close() {
    _resting?.cancel();
    return super.close();
  }
}

final class PlacePickerState extends Equatable {
  const PlacePickerState({
    this.point,
    this.place,
    this.naming = false,
    this.locating = false,
    this.locationProblem,
  });

  /// Where the pin is; null until the user chooses.
  final LatLng? point;

  /// What it is called, when known.
  final JourneyPlace? place;
  final bool naming;
  final bool locating;
  final LocationAccess? locationProblem;

  @override
  List<Object?> get props => <Object?>[
    point,
    place,
    naming,
    locating,
    locationProblem,
  ];
}
