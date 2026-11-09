import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/route_progress.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';

/// The numbers on the panel. Remaining distance and arrival appear only when
/// the position sits on a planned route.
class JourneyMapFigures extends StatelessWidget {
  const JourneyMapFigures({required this.state, super.key});

  final JourneyMapState state;

  @override
  Widget build(BuildContext context) {
    final double? kmh = state.speed.kmh;
    final double? metres = state.distanceMeters;
    final RouteProgress? progress = state.progress;
    final double? seconds = progress?.remainingSeconds;
    final bool live = state.status != MapTrackingStatus.completed;

    return Wrap(
      spacing: 22.fx,
      runSpacing: 8.fx,
      children: <Widget>[
        if (live)
          _Figure(
            label: context.tr('journeys.map.speed'),
            value: kmh == null
                ? context.tr('journeys.map.noValue')
                : TrackingLabels.speed(context, kmh),
          ),
        if (metres != null)
          _Figure(
            label: context.tr('journeys.map.travelled'),
            value: TrackingLabels.distance(context, metres),
          ),
        if (live && progress != null)
          _Figure(
            label: context.tr('journeys.map.remaining'),
            value: TrackingLabels.distance(context, progress.remainingMeters),
          ),
        if (live && seconds != null)
          _Figure(
            label: context.tr('journeys.map.arrival'),
            value: MapLabels.clock(
              context,
              DateTime.now().add(Duration(seconds: seconds.round())),
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        Text(
          value,
          style: context.texts.titleSmall?.copyWith(
            color: context.appColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
