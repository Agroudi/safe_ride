import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';

/// From and To, joined by a quiet line — the review and details screens.
/// [trailing] sits under the places (a status chip, dates).
class JourneyRouteCard extends StatelessWidget {
  const JourneyRouteCard({
    required this.fromLabel,
    required this.from,
    required this.toLabel,
    required this.to,
    this.trailing,
    super.key,
  });

  final String fromLabel;
  final String from;
  final String toLabel;
  final String to;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget? extra = trailing;

    return Container(
      padding: EdgeInsets.all(18.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Stop(
            icon: Icons.trip_origin_rounded,
            color: colors.secondary,
            label: fromLabel,
            place: from,
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: 11.fx),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 2.fx,
                height: 22.fx,
                color: colors.border,
              ),
            ),
          ),
          _Stop(
            icon: Icons.place_rounded,
            color: colors.primary,
            label: toLabel,
            place: to,
          ),
          if (extra != null) ...<Widget>[
            Gap(16.fx),
            Divider(height: 1, color: colors.border),
            Gap(14.fx),
            extra,
          ],
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.color,
    required this.label,
    required this.place,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String place;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 24.fx, color: color),
          Gap(12.fx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                Gap(2.fx),
                Text(
                  JourneyLabels.place(place),
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
