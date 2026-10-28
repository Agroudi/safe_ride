import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_status_chip.dart';

/// What a `JourneyTile` shows: the route glyph, where to (two lines at most),
/// where from, the departure, and the status chip.
class JourneyTileBody extends StatelessWidget {
  const JourneyTileBody({
    required this.origin,
    required this.destination,
    required this.dateLabel,
    required this.statusLabel,
    required this.statusColor,
    super.key,
  });

  final String origin;
  final String destination;
  final String dateLabel;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Row(
      children: <Widget>[
        Container(
          width: 42.fx,
          height: 42.fx,
          decoration: BoxDecoration(
            color: colors.tint(colors.secondary),
            borderRadius: BorderRadius.circular(14.fx),
          ),
          child: Icon(
            Icons.route_rounded,
            size: 22.fx,
            color: colors.accentText,
          ),
        ),
        Gap(12.fx),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2.fx,
            children: <Widget>[
              // Two lines, so a long place still reads at large text.
              Text(
                JourneyLabels.place(destination),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleSmall?.copyWith(color: colors.text),
              ),
              Text(
                JourneyLabels.place(origin),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              Text(
                dateLabel,
                style: context.texts.labelSmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Gap(8.fx),
        JourneyStatusChip(label: statusLabel, color: statusColor),
      ],
    );
  }
}
