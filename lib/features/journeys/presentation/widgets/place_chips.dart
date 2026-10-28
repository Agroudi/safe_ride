import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';

/// Places the user typed before, offered back under a field — only ever
/// their own words from past journeys, never a suggestion SafeRide made up.
/// Draws nothing when there are none.
class PlaceChips extends StatelessWidget {
  const PlaceChips({
    required this.label,
    required this.places,
    required this.onPick,
    super.key,
  });

  final String label;
  final List<String> places;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 10.fx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          Gap(6.fx),
          Wrap(
            spacing: 8.fx,
            runSpacing: 8.fx,
            children: <Widget>[
              for (final String place in places)
                ActionChip(
                  label: Text(JourneyLabels.place(place)),
                  onPressed: () => onPick(place),
                  backgroundColor: context.appColors.surface,
                  side: BorderSide(color: context.appColors.border),
                  labelStyle: context.texts.bodySmall?.copyWith(
                    color: context.appColors.text,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
