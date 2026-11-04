import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// One figure of the recording: a small label, the value, and an optional
/// caption saying how fresh it is. Read as one sentence by a screen reader.
class TrackingStat extends StatelessWidget {
  const TrackingStat({
    required this.label,
    required this.value,
    this.caption,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.appColors.textMuted;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: context.texts.labelSmall?.copyWith(color: muted)),
          Gap(4.fx),
          Text(
            value,
            style: context.texts.titleMedium?.copyWith(
              color: context.appColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (caption case final String line) ...<Widget>[
            Gap(2.fx),
            Text(line, style: context.texts.labelSmall?.copyWith(color: muted)),
          ],
        ],
      ),
    );
  }
}
