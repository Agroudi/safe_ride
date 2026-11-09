import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/logic/cubit/route_preview_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_labels.dart';

/// Under the planning map: the provider's estimate, or why there is none.
class RouteSummaryLine extends StatelessWidget {
  const RouteSummaryLine({required this.state, super.key});

  final RoutePreviewState state;

  @override
  Widget build(BuildContext context) {
    final PlannedRoute? route = state.route;
    final MapFailureCode? failure = state.failure;
    final String? text = route != null
        ? MapLabels.routeSummary(
            context,
            metres: route.distanceMeters,
            seconds: route.durationSeconds,
          )
        : failure != null
        ? MapLabels.routeFailure(context, failure)
        : state.loading
        ? context.tr('journeys.map.route.loading')
        : null;
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 8.fx),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: context.texts.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ),
          if (failure != null) ...<Widget>[
            Gap(8.fx),
            TextButton(
              onPressed: context.read<RoutePreviewCubit>().retry,
              child: Text(context.tr('journeys.map.retry')),
            ),
          ],
        ],
      ),
    );
  }
}
