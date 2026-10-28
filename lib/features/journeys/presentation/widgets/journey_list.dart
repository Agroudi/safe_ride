import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_tile.dart';

/// Journeys as tiles, newest first — home's recent three and My Journeys'
/// full history. The words on each tile come from the journey itself
/// (`JourneyLabels`). With [onCancel], each planned journey offers Cancel.
class JourneyList extends StatelessWidget {
  const JourneyList({
    required this.journeys,
    required this.onOpen,
    this.limit,
    this.onCancel,
    super.key,
  });

  final List<JourneyModel> journeys;
  final ValueChanged<JourneyModel> onOpen;

  /// Show at most this many.
  final int? limit;

  final ValueChanged<JourneyModel>? onCancel;

  @override
  Widget build(BuildContext context) {
    final Iterable<JourneyModel> shown = limit == null
        ? journeys
        : journeys.take(limit!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10.fx,
      children: <Widget>[
        for (final JourneyModel j in shown)
          JourneyTile(
            key: ValueKey<String>(j.id),
            origin: j.origin,
            destination: j.destination,
            dateLabel: JourneyLabels.departure(context, j.departsAt),
            statusLabel: JourneyLabels.status(context, j.status),
            statusColor: JourneyLabels.tone(context.appColors, j.status),
            onTap: () => onOpen(j),
            onCancel: onCancel == null || j.status != JourneyStatus.planned
                ? null
                : () => onCancel!(j),
            cancelLabel: context.tr('journeys.detail.cancel'),
            moreLabel: context.tr('journeys.more'),
          ),
      ],
    );
  }
}
