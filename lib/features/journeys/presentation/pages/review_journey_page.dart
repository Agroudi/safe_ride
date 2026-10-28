import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';
import 'package:safe_ride/features/journeys/logic/cubit/plan_journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/plan_journey_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_facts.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_notices.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_route_card.dart';

/// The last step before a journey exists: the places and the departure as
/// they will be saved. Confirm saves it as *Planned* and opens its details (home stays
/// under it, so back goes home); Cancel discards the plan; back edits it.
class ReviewJourneyPage extends StatelessWidget {
  const ReviewJourneyPage({required this.draft, super.key});

  final JourneyDraft draft;

  @override
  Widget build(BuildContext context) => BlocProvider<PlanJourneyCubit>(
    create: (_) => sl<PlanJourneyCubit>(),
    child: _ReviewJourneyView(draft: draft),
  );
}

class _ReviewJourneyView extends StatelessWidget {
  const _ReviewJourneyView({required this.draft});

  final JourneyDraft draft;

  void _onState(BuildContext context, PlanJourneyState state) {
    switch (state) {
      case PlanJourneySaved(:final journey):
        sl<AppNotifier>().show(JourneyNotices.planned(context));
        // Plan and review leave the stack: back from the details is home.
        GoRouter.of(context)
          ..goNamed(AppRoutes.home)
          ..pushNamed(
            AppRoutes.journey,
            pathParameters: <String, String>{'id': journey.id},
          );
      case PlanJourneyFailed(:final code):
        sl<AppNotifier>().show(JourneyNotices.failure(context, code));
      case PlanJourneyIdle() || PlanJourneySaving():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlanJourneyCubit, PlanJourneyState>(
      listener: _onState,
      builder: (BuildContext context, PlanJourneyState state) {
        final bool busy =
            state is PlanJourneySaving || state is PlanJourneySaved;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenSide,
                AppSpacing.screenTop,
                AppSpacing.screenSide,
                24.fx,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TitleBar(title: context.tr('journeys.review.title')),
                  Gap(24.fx),
                  JourneyRouteCard(
                    fromLabel: context.tr('journeys.from'),
                    from: draft.origin.trim(),
                    toLabel: context.tr('journeys.to'),
                    to: draft.destination.trim(),
                    trailing: JourneyDeparture(departsAt: draft.departsAt),
                  ),
                  Gap(20.fx),
                  InfoNote(text: context.tr('journeys.notTracked')),
                  Gap(28.fx),
                  AppPrimaryButton(
                    label: context.tr('journeys.review.confirm'),
                    busy: busy,
                    onPressed: () =>
                        context.read<PlanJourneyCubit>().confirm(draft),
                  ),
                  Gap(12.fx),
                  AppPrimaryButton(
                    label: context.tr('journeys.review.discard'),
                    outlined: true,
                    onPressed: busy
                        ? null
                        : () => context.goNamed(AppRoutes.home),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
