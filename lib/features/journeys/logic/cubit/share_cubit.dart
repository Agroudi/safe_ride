import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/location_share.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/location_sharing.dart';

sealed class ShareState extends Equatable {
  const ShareState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class ShareIdle extends ShareState {
  const ShareIdle();
}

final class ShareStarting extends ShareState {
  const ShareStarting();
}

final class ShareActive extends ShareState {
  const ShareActive(this.status);

  final ShareStatus status;

  @override
  List<Object?> get props => <Object?>[status];
}

final class ShareFailed extends ShareState {
  const ShareFailed(this.code);

  final ShareFailureCode code;

  @override
  List<Object?> get props => <Object?>[code];
}

/// The user stopped it. [confirmed] false: the link ends when the phone is
/// back online, or when it expires, whichever comes first.
final class ShareStopped extends ShareState {
  const ShareStopped({required this.confirmed});

  final bool confirmed;

  @override
  List<Object?> get props => <Object?>[confirmed];
}

/// One screen's view of [LocationSharing]. One per screen.
class ShareCubit extends Cubit<ShareState> {
  ShareCubit(this._sharing, this._tracker, this._journeys)
    : super(_of(_sharing.current)) {
    _changes = _sharing.changes.listen((ShareStatus? status) {
      if (status != null) {
        emit(ShareActive(status));
      } else if (state is ShareActive) {
        emit(const ShareIdle());
      }
    });
  }

  static ShareState _of(ShareStatus? status) =>
      status == null ? const ShareIdle() : ShareActive(status);

  final LocationSharing _sharing;
  final JourneyTracker _tracker;
  final JourneyRepository _journeys;
  late final StreamSubscription<ShareStatus?> _changes;

  /// The user's tap on Start: the screen has said what is shared, so this is
  /// where the system's prompts belong. Always asked, granted or not: location
  /// answers at once, and without the notifications one, Android hides the
  /// notice that tells the user their location is being used.
  Future<void> start(ShareDuration duration, {String? journeyId}) async {
    if (state is ShareStarting) return;
    emit(const ShareStarting());
    try {
      if (await _tracker.requestAccess() != LocationAccess.granted) {
        throw const ShareFailure(ShareFailureCode.noAccess);
      }
      await _sharing.start(
        duration: duration,
        journey: journeyId == null ? null : await _journey(journeyId),
      );
      final ShareStatus? now = _sharing.current;
      if (!isClosed && now != null) emit(ShareActive(now));
    } on ShareFailure catch (e) {
      if (!isClosed) emit(ShareFailed(e.code));
    }
  }

  Future<JourneyModel> _journey(String id) async {
    try {
      final JourneyModel? journey = await _journeys.journey(id);
      if (journey != null) return journey;
    } on JourneyFailure {
      // Told the same way: this journey cannot be shared.
    }
    throw const ShareFailure(ShareFailureCode.notActive);
  }

  Future<void> stop() async {
    final bool confirmed = await _sharing.stop();
    if (!isClosed) emit(ShareStopped(confirmed: confirmed));
  }

  /// Location settings, for when access was refused for good.
  Future<void> openSettings() => _tracker.openAppSettings();

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
