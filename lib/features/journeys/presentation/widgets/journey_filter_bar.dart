import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// All, then one choice per status the model has — never a filter for a
/// state that does not exist. [selected] null is All.
class JourneyFilterBar extends StatelessWidget {
  const JourneyFilterBar({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final JourneyStatus? selected;
  final ValueChanged<JourneyStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final List<(JourneyStatus?, String)> options = <(JourneyStatus?, String)>[
      (null, 'all'),
      for (final JourneyStatus s in JourneyStatus.values) (s, s.name),
    ];

    return Semantics(
      container: true,
      label: context.tr('journeys.filter.label'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: 8.fx,
          children: <Widget>[
            for (final (JourneyStatus? status, String key) in options)
              ChoiceChip(
                label: Text(context.tr('journeys.filter.$key')),
                selected: status == selected,
                onSelected: (_) => onSelected(status),
                showCheckmark: false,
                selectedColor: colors.tint(colors.secondary),
                backgroundColor: colors.surface,
                side: BorderSide(
                  color: status == selected ? colors.secondary : colors.border,
                ),
                labelStyle: context.texts.labelMedium?.copyWith(
                  color: status == selected ? colors.accentText : colors.text,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
