import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/journeys/data/models/journey_checklist.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_start_state.dart';

/// The pre-journey checklist for one planned journey: every item starts
/// unconfirmed (a new screen, a new checklist — nothing carries over from a
/// previous journey or a previous visit), the user confirms each one, and
/// only a complete checklist starts the journey. The repository and the
/// Security Rules check the same again; this is the user's feedback.
class JourneyStartCubit extends Cubit<JourneyStartState> {
  JourneyStartCubit(this._repository) : super(const JourneyStartLoading());

  final JourneyRepository _repository;

  /// The version this screen asks.
  static const int version = JourneyChecklist.current;

  /// [version]'s items, in order.
  static List<String> get items => JourneyChecklist.itemsOf(version);

  Future<void> load(String id) async {
    try {
      final JourneyModel? journey = await _repository.journey(id);
      if (isClosed) return;
      emit(switch (journey?.status) {
        JourneyStatus.planned => JourneyStartFilling(
          journey!,
          const <String>{},
        ),
        JourneyStatus.active => const JourneyStartUnavailable(
          JourneyFailureCode.alreadyStarted,
        ),
        JourneyStatus.completed || JourneyStatus.cancelled =>
          const JourneyStartUnavailable(JourneyFailureCode.notPlanned),
        null => const JourneyStartUnavailable(JourneyFailureCode.notFound),
      });
    } on JourneyFailure catch (e) {
      if (!isClosed) emit(JourneyStartUnavailable(e.code));
    }
  }

  /// Confirms [item], or takes the confirmation back. Ignored while starting.
  void toggle(String item) {
    final (JourneyModel, Set<String>)? now = _editable;
    if (now == null || !items.contains(item)) return;
    final Set<String> next = Set<String>.of(now.$2);
    if (!next.remove(item)) next.add(item);
    emit(JourneyStartFilling(now.$1, Set<String>.unmodifiable(next)));
  }

  /// Saves the checklist and starts the journey — once: a second tap while
  /// it saves, or an incomplete checklist, does nothing.
  Future<void> start() async {
    final (JourneyModel, Set<String>)? now = _editable;
    if (now == null || !JourneyChecklist.isComplete(version, now.$2)) return;
    final (JourneyModel journey, Set<String> confirmed) = now;
    emit(JourneyStartFilling(journey, confirmed, starting: true));
    try {
      final ({JourneyModel journey, bool synced}) result = await _repository
          .start(journey.id, checklistVersion: version, confirmed: confirmed);
      if (!isClosed) {
        emit(JourneyStartStarted(result.journey, synced: result.synced));
      }
    } on JourneyFailure catch (e) {
      if (isClosed) return;
      emit(switch (e.code) {
        // Started or closed elsewhere meanwhile: this checklist is over.
        JourneyFailureCode.alreadyStarted ||
        JourneyFailureCode.notPlanned ||
        JourneyFailureCode.notFound => JourneyStartUnavailable(e.code),
        _ => JourneyStartFailed(journey, confirmed, e.code),
      });
    }
  }

  (JourneyModel, Set<String>)? get _editable => switch (state) {
    JourneyStartFilling(
      :final JourneyModel journey,
      :final Set<String> confirmed,
      starting: false,
    ) =>
      (journey, confirmed),
    JourneyStartFailed(
      :final JourneyModel journey,
      :final Set<String> confirmed,
    ) =>
      (journey, confirmed),
    _ => null,
  };
}
