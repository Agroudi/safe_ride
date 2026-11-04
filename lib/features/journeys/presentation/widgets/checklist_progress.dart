import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// How much of the checklist is confirmed: [label] ("3 of 9 confirmed")
/// over a bar that turns to the success colour when [done] reaches [total],
/// and [hint] — what is still needed, or that it is complete.
class ChecklistProgress extends StatelessWidget {
  const ChecklistProgress({
    required this.done,
    required this.total,
    required this.label,
    required this.hint,
    super.key,
  });

  final int done;
  final int total;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool complete = total > 0 && done >= total;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label. $hint',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              label,
              style: context.texts.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            Gap(8.fx),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.fx),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 8.fx,
                color: complete ? colors.success : colors.primary,
                backgroundColor: colors.tint(colors.primary),
              ),
            ),
            Gap(8.fx),
            Text(
              hint,
              style: context.texts.bodySmall?.copyWith(
                color: complete ? colors.text : colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
