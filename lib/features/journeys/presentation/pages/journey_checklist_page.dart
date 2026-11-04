import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_start_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_start_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_checklist_form.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_notices.dart';

/// The pre-journey safety checklist: the only way a planned journey starts.
/// Every visit begins unconfirmed. Leaving without starting — Not now or
/// back — keeps the journey planned, and says so.
class JourneyChecklistPage extends StatelessWidget {
  const JourneyChecklistPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => BlocProvider<JourneyStartCubit>(
    create: (_) => sl<JourneyStartCubit>()..load(id),
    child: const _ChecklistView(),
  );
}

class _ChecklistView extends StatelessWidget {
  const _ChecklistView();

  /// A start attempt ended: started, failed, or found the journey changed.
  static bool _answered(JourneyStartState before, JourneyStartState now) =>
      before is JourneyStartFilling &&
      before.starting &&
      now is! JourneyStartFilling;

  void _onState(BuildContext context, JourneyStartState state) {
    switch (state) {
      case JourneyStartStarted(:final bool synced):
        sl<AppNotifier>().show(JourneyNotices.started(context, synced: synced));
        context.pop();
      case JourneyStartFailed(:final JourneyFailureCode code) ||
          JourneyStartUnavailable(:final JourneyFailureCode code):
        sl<AppNotifier>().show(JourneyNotices.failure(context, code));
      case JourneyStartLoading() || JourneyStartFilling():
        break;
    }
  }

  /// Left with the checklist open (back, or Not now): nothing started.
  void _onPop(BuildContext context, bool didPop) {
    final JourneyStartState state = context.read<JourneyStartCubit>().state;
    if (didPop &&
        (state is JourneyStartFilling || state is JourneyStartFailed)) {
      sl<AppNotifier>().show(JourneyNotices.notStarted(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final JourneyStartCubit cubit = context.read<JourneyStartCubit>();

    return BlocConsumer<JourneyStartCubit, JourneyStartState>(
      listenWhen: _answered,
      listener: _onState,
      builder: (BuildContext context, JourneyStartState state) =>
          PopScope<Object?>(
            // Not while it starts: the write is on its way, and leaving would say
            // "not started" about a journey that is.
            canPop: !(state is JourneyStartFilling && state.starting),
            onPopInvokedWithResult: (bool didPop, _) => _onPop(context, didPop),
            child: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.screenSide,
                    AppSpacing.screenTop,
                    AppSpacing.screenSide,
                    24.fx,
                  ),
                  children: <Widget>[
                    TitleBar(title: context.tr('journeys.checklist.title')),
                    Gap(20.fx),
                    switch (state) {
                      JourneyStartFilling(:final journey, :final confirmed) ||
                      JourneyStartFailed(
                        :final journey,
                        :final confirmed,
                      ) => JourneyChecklistForm(
                        journey: journey,
                        version: JourneyStartCubit.version,
                        items: JourneyStartCubit.items,
                        confirmed: confirmed,
                        starting:
                            state is JourneyStartFilling && state.starting,
                        onToggle: cubit.toggle,
                        onStart: cubit.start,
                        onNotNow: () => context.pop(),
                      ),
                      JourneyStartUnavailable(:final JourneyFailureCode code) =>
                        _Unavailable(code: code),
                      JourneyStartLoading() || JourneyStartStarted() =>
                        const Center(child: CircularProgressIndicator()),
                    },
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

/// Why this journey cannot start from here.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.code});

  final JourneyFailureCode code;

  @override
  Widget build(BuildContext context) {
    final bool missing = code == JourneyFailureCode.notFound;

    return AppEmptyState(
      icon: missing ? Icons.search_off_rounded : Icons.lock_outline_rounded,
      title: context.tr(
        missing
            ? 'journeys.detail.missingTitle'
            : 'journeys.checklist.unavailable',
      ),
      body: context.tr(
        missing
            ? 'journeys.detail.missingBody'
            : JourneyNotices.messageKey(code),
      ),
    );
  }
}
