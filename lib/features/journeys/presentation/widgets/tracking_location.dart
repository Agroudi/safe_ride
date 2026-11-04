import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';

/// The latest trusted position, as current only while fixes are fresh.
class TrackingLocation extends StatelessWidget {
  const TrackingLocation({super.key, required this.point, required this.fresh});

  final TrackPoint? point;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final TrackPoint? p = point;
    final Color muted = context.appColors.textMuted;
    if (p == null) {
      return Text(
        context.tr('journeys.tracking.waiting'),
        style: context.texts.bodySmall?.copyWith(color: muted),
      );
    }
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.tr(
              fresh
                  ? 'journeys.tracking.location'
                  : 'journeys.tracking.lastLocation',
            ),
            style: context.texts.labelSmall?.copyWith(color: muted),
          ),
          Gap(4.fx),
          Text(
            TrackingLabels.coordinates(context, p),
            style: context.texts.bodySmall?.copyWith(
              color: context.appColors.text,
            ),
          ),
          Text(
            TrackingLabels.accuracy(context, p.accuracy),
            style: context.texts.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
