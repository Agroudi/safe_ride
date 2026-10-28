import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_actions.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_facts.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_notices.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_route_card.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';

/// One journey: its places, status and dates, and — while it is planned —
/// the user's own two endings. Nothing changes the status but the user.
class JourneyPage extends StatelessWidget {
  const JourneyPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => BlocProvider<JourneyCubit>(
    create: (_) => sl<JourneyCubit>()..load(id),
    child: const _JourneyView(),
  );
}

class _JourneyView extends StatelessWidget {
  const _JourneyView();

  /// A status change landed: the busy state cleared on a new status.
  static bool _settled(JourneyState before, JourneyState now) =>
      before is JourneyReady &&
      before.busy &&
      now is JourneyReady &&
      now.journey.status != JourneyStatus.planned;

  void _onState(BuildContext context, JourneyState state) {
    if (state is JourneyFailed && state.journey != null) {
      sl<AppNotifier>().show(JourneyNotices.failure(context, state.code));
    } else if (state is JourneyReady) {
      sl<AppNotifier>().show(
        state.journey.status == JourneyStatus.completed
            ? JourneyNotices.completed(context)
            : JourneyNotices.cancelled(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JourneyCubit, JourneyState>(
      listenWhen: (JourneyState a, JourneyState b) =>
          _settled(a, b) || b is JourneyFailed,
      listener: _onState,
      builder: (BuildContext context, JourneyState state) {
        final JourneyModel? journey = switch (state) {
          JourneyReady(:final JourneyModel journey) => journey,
          JourneyFailed(:final JourneyModel? journey) => journey,
          _ => null,
        };
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenSide,
                AppSpacing.screenTop,
                AppSpacing.screenSide,
                24.fx,
              ),
              children: <Widget>[
                TitleBar(title: context.tr('journeys.detail.title')),
                Gap(24.fx),
                if (journey != null) ...<Widget>[
                  JourneyRouteCard(
                    fromLabel: context.tr('journeys.from'),
                    from: journey.origin,
                    toLabel: context.tr('journeys.to'),
                    to: journey.destination,
                    trailing: JourneyFacts(journey: journey),
                  ),
                  Gap(20.fx),
                  InfoNote(text: context.tr('journeys.notTracked')),
                  Gap(28.fx),
                  if (journey.status == JourneyStatus.planned)
                    JourneyActions(
                      busy: state is JourneyReady && state.busy,
                      onEdit: () => context.pushNamed(
                        AppRoutes.editJourney,
                        pathParameters: <String, String>{'id': journey.id},
                      ),
                    )
                  else
                    Text(
                      context.tr('journeys.detail.settled'),
                      textAlign: TextAlign.center,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                ] else if (state is JourneyLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: context.tr('journeys.detail.missingTitle'),
                    body: context.tr(
                      state is JourneyMissing
                          ? 'journeys.detail.missingBody'
                          : 'journeys.failed.body',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
