import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_location_state.dart';

/// The "Where you are" card: what is already known on open, one new reading
/// on the user's tap, and a clock so a reading ages on screen. It never asks
/// for permission and sends nothing: the coordinates are for the user to read
/// out or copy. One per screen.
class EmergencyLocationCubit extends Cubit<EmergencyLocationState> {
  EmergencyLocationCubit(
    this._reader, {
    DateTime Function()? clock,
    Duration? tick = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now,
       super(EmergencyLocationState(now: (clock ?? DateTime.now)().toUtc())) {
    if (tick != null) {
      _ticker = Timer.periodic(tick, (_) => this.tick());
    }
  }

  final EmergencyPositionReader _reader;
  final DateTime Function() _clock;
  Timer? _ticker;

  Future<void> load() async {
    final EmergencyPosition position = await _reader.lastKnown();
    if (isClosed) return;
    emit(
      state.copyWith(now: _clock().toUtc(), loading: false, position: position),
    );
  }

  /// One reading now. Taps while one is under way are ignored.
  Future<void> locate() async {
    if (state.locating) return;
    emit(state.copyWith(locating: true, notFound: false));
    final EmergencyPosition position = await _reader.locateNow();
    if (isClosed) return;
    final PositionReading? found = position.reading;
    emit(
      EmergencyLocationState(
        now: _clock().toUtc(),
        loading: false,
        // Nothing new: keep showing what was known, labelled by its age.
        position: found == null
            ? EmergencyPosition(
                access: position.access,
                reading: state.reading,
                destination: position.destination,
              )
            : position,
        notFound: found == null,
      ),
    );
  }

  /// Moves the clock on, so ages and freshness stay true.
  void tick() {
    if (!isClosed) emit(state.copyWith(now: _clock().toUtc()));
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
