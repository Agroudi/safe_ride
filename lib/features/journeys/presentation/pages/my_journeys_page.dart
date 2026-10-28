import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_filter_bar.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_notices.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journeys_content.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';

/// The My Journeys tab: every journey planned on this phone, newest first,
/// filtered by status, or an empty state that offers the first one. A
/// planned journey can be cancelled from its tile, after a confirmation.
/// Reloads by itself whenever a journey is planned or changes.
class MyJourneysPage extends StatelessWidget {
  const MyJourneysPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<JourneysCubit>(
    create: (_) => sl<JourneysCubit>()..load(),
    child: const _MyJourneysView(),
  );
}

class _MyJourneysView extends StatefulWidget {
  const _MyJourneysView();

  @override
  State<_MyJourneysView> createState() => _MyJourneysViewState();
}

class _MyJourneysViewState extends State<_MyJourneysView> {
  /// Null shows every journey.
  JourneyStatus? _filter;

  Future<void> _cancel(JourneyModel journey) async {
    final JourneysCubit journeys = context.read<JourneysCubit>();
    final bool yes = await showAppConfirmDialog(
      context,
      title: context.tr('journeys.confirmCancel.title'),
      message: context.tr('journeys.confirmCancel.message'),
      confirmLabel: context.tr('journeys.confirmCancel.confirm'),
      cancelLabel: context.tr('journeys.confirmCancel.cancel'),
      destructive: true,
    );
    if (!yes) return;
    final JourneyFailureCode? failure = await journeys.cancel(journey.id);
    if (!mounted) return;
    sl<AppNotifier>().show(
      failure == null
          ? JourneyNotices.cancelled(context)
          : JourneyNotices.failure(context, failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JourneyStatus? filter = _filter;

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<JourneysCubit, JourneysState>(
          builder: (BuildContext context, JourneysState state) => ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenSide,
              AppSpacing.screenTop,
              AppSpacing.screenSide,
              28.fx,
            ),
            children: <Widget>[
              Semantics(
                container: true,
                header: true,
                child: Text(
                  context.tr('journeys.title'),
                  style: context.texts.titleLarge,
                ),
              ),
              Gap(16.fx),
              if (state is JourneysReady &&
                  state.journeys.isNotEmpty) ...<Widget>[
                JourneyFilterBar(
                  selected: filter,
                  onSelected: (JourneyStatus? s) => setState(() => _filter = s),
                ),
                Gap(16.fx),
              ],
              JourneysContent(
                state: state,
                where: filter == null
                    ? null
                    : (JourneyModel j) => j.status == filter,
                empty: AppEmptyState(
                  icon: Icons.route_rounded,
                  title: context.tr('journeys.empty.title'),
                  body: context.tr('journeys.empty.body'),
                  actionLabel: context.tr('journeys.empty.action'),
                  onAction: () => context.pushNamed(AppRoutes.planJourney),
                ),
                filteredEmpty: filter == null
                    ? null
                    : AppEmptyState(
                        icon: Icons.filter_list_rounded,
                        title: context.tr(
                          'journeys.filter.empty.${filter.name}',
                        ),
                        body: context.tr('journeys.empty.body'),
                      ),
                failedTitle: context.tr('journeys.failed.title'),
                failedBody: context.tr('journeys.failed.body'),
                retryLabel: context.tr('journeys.failed.retry'),
                onRetry: context.read<JourneysCubit>().load,
                onCancel: _cancel,
                onOpen: (JourneyModel j) => context.pushNamed(
                  AppRoutes.journey,
                  pathParameters: <String, String>{'id': j.id},
                ),
              ),
              Gap(20.fx),
              InfoNote(text: context.tr('journeys.notTracked')),
            ],
          ),
        ),
      ),
    );
  }
}
