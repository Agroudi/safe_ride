import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/home_header.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/home_safety_section.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journeys_content.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/plan_journey_card.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';

/// The signed-in dashboard: a greeting, the journey card, the three most
/// recent journeys, and the safety features — each marked *Planned* until it
/// exists. Everything shown is real data or says plainly that it is not
/// there yet. One staged entrance per arrival.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<JourneysCubit>(
    create: (_) => sl<JourneysCubit>()..load(),
    child: const _HomeView(),
  );
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  /// 05:00–11:59 morning, 12:00–16:59 afternoon, the rest evening.
  static String _partOfDay(int hour) => switch (hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    _ => 'evening',
  };

  void _open(BuildContext context, JourneyModel journey) => context.pushNamed(
    AppRoutes.journey,
    pathParameters: <String, String>{'id': journey.id},
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JourneysCubit, JourneysState>(
      builder: (BuildContext context, JourneysState state) {
        final String? name = switch (state) {
          JourneysReady(:final String? firstName) => firstName,
          JourneysFailed(:final String? firstName) => firstName,
          JourneysLoading() => null,
        };
        final String part = _partOfDay(DateTime.now().hour);
        return Scaffold(
          body: SafeArea(
            child: EntranceScope(
              duration: AppDurations.entrance,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenSide,
                  16.fx,
                  AppSpacing.screenSide,
                  28.fx,
                ),
                children: <Widget>[
                  EntranceItem.beat(
                    0,
                    rise: AppMotion.riseSmall,
                    child: HomeHeader(
                      greeting: name == null
                          ? context.tr('home.greetingPlain.$part')
                          : context.tr(
                              'home.greeting.$part',
                              namedArgs: <String, String>{'name': name},
                            ),
                      subtitle: context.tr('home.subtitle'),
                      initial: name?.characters.first.toUpperCase(),
                      avatarLabel: context.tr('home.avatarLabel'),
                      onAvatar: () => context.goNamed(AppRoutes.profile),
                    ),
                  ),
                  Gap(22.fx),
                  EntranceItem.beat(
                    1,
                    rise: AppMotion.rise,
                    child: PlanJourneyCard(
                      title: context.tr('home.plan.title'),
                      body: context.tr('home.plan.body'),
                      actionLabel: context.tr('home.plan.action'),
                      onStart: () => context.pushNamed(AppRoutes.planJourney),
                    ),
                  ),
                  Gap(28.fx),
                  EntranceItem.beat(
                    2,
                    rise: AppMotion.rise,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SectionHeading(
                          title: context.tr('home.recent.title'),
                          actionLabel:
                              state is JourneysReady &&
                                  state.journeys.isNotEmpty
                              ? context.tr('home.recent.seeAll')
                              : null,
                          onAction: () => context.goNamed(AppRoutes.myJourneys),
                        ),
                        Gap(8.fx),
                        JourneysContent(
                          state: state,
                          limit: 3,
                          empty: AppEmptyState(
                            icon: Icons.route_rounded,
                            title: context.tr('home.recent.emptyTitle'),
                            body: context.tr('home.recent.emptyBody'),
                          ),
                          failedTitle: context.tr('journeys.failed.title'),
                          failedBody: context.tr('journeys.failed.body'),
                          retryLabel: context.tr('journeys.failed.retry'),
                          onRetry: context.read<JourneysCubit>().load,
                          onOpen: (JourneyModel j) => _open(context, j),
                        ),
                      ],
                    ),
                  ),
                  Gap(28.fx),
                  const EntranceItem.beat(
                    3,
                    rise: AppMotion.rise,
                    child: HomeSafetySection(),
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
