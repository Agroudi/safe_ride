import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_status_chip.dart';

/// Under a journey's places: its departure, its status, when it was
/// planned, and when it last changed (only when it has).
class JourneyFacts extends StatelessWidget {
  const JourneyFacts({required this.journey, super.key});

  final JourneyModel journey;

  @override
  Widget build(BuildContext context) {
    final TextStyle? quiet = context.texts.bodySmall?.copyWith(
      color: context.appColors.textMuted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        JourneyDeparture(departsAt: journey.departsAt),
        Gap(14.fx),
        JourneyStatusChip(
          label: JourneyLabels.status(context, journey.status),
          color: JourneyLabels.tone(context.appColors, journey.status),
        ),
        Gap(10.fx),
        Text(
          '${context.tr('journeys.detail.created')} '
          '${JourneyLabels.date(context, journey.createdAt)}',
          style: quiet,
        ),
        if (journey.updatedAt != journey.createdAt)
          Text(
            '${context.tr('journeys.detail.updated')} '
            '${JourneyLabels.date(context, journey.updatedAt)}',
            style: quiet,
          ),
      ],
    );
  }
}

/// The departure as a labelled line with a clock — review and details.
class JourneyDeparture extends StatelessWidget {
  const JourneyDeparture({required this.departsAt, super.key});

  /// UTC; null on a journey stored before departures existed.
  final DateTime? departsAt;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            size: 22.fx,
            color: context.appColors.accentText,
          ),
          Gap(12.fx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.tr('journeys.departure'),
                  style: context.texts.labelSmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                Gap(2.fx),
                Text(
                  JourneyLabels.departure(context, departsAt),
                  style: context.texts.titleSmall?.copyWith(
                    color: context.appColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
