import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Three segments, one per password rule met (length, a digit, a capital) —
/// the same three rules the validator enforces, so a full bar means the
/// password will be accepted.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({required this.score, super.key});

  /// 0 to 3, from `Validators.passwordScore`.
  final int score;

  static const int segments = 3;

  Color _fill(AppColors colors) => switch (score) {
    1 => colors.error,
    2 => colors.warning,
    _ => colors.success,
  };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Row(
      children: <Widget>[
        for (int i = 0; i < segments; i++) ...<Widget>[
          if (i > 0) Gap(8.fx),
          Expanded(
            child: AnimatedContainer(
              duration: AppDurations.short,
              height: 6.fx,
              decoration: BoxDecoration(
                color: i < score ? _fill(colors) : colors.border,
                borderRadius: BorderRadius.circular(99.fx),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
