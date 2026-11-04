import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The line every emergency screen opens with: [text], on a quiet wash of
/// the warning colour.
class EmergencyWarning extends StatelessWidget {
  const EmergencyWarning({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(14.fx),
      decoration: BoxDecoration(
        color: colors.tint(colors.warning),
        borderRadius: BorderRadius.circular(16.fx),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 20.fx, color: colors.text),
          Gap(10.fx),
          Expanded(
            child: Text(
              text,
              style: context.texts.bodySmall?.copyWith(
                color: colors.text,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
