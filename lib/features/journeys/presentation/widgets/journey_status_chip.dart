import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A small rounded label: the status word on a wash of its colour. Also the
/// "Planned" badge on a safety feature that is not built yet.
class JourneyStatusChip extends StatelessWidget {
  const JourneyStatusChip({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.fx, vertical: 4.fx),
      decoration: BoxDecoration(
        color: context.appColors.tint(color),
        borderRadius: BorderRadius.circular(20.fx),
      ),
      child: Text(
        label,
        style: context.texts.labelSmall?.copyWith(
          // The text stays a readable role; the wash carries the hue.
          color: context.appColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
