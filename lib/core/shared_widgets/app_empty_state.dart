import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// A calm card for "nothing here yet" or "could not load": an icon on a
/// wash, a title, one line, and an optional action. Never fake content.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? action = actionLabel;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.fx, vertical: 24.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56.fx,
            height: 56.fx,
            decoration: BoxDecoration(
              color: colors.tint(colors.secondary),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28.fx, color: colors.accentText),
          ),
          Gap(14.fx),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.texts.titleSmall?.copyWith(color: colors.text),
          ),
          Gap(6.fx),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: colors.textMuted,
              height: 1.6,
            ),
          ),
          if (action != null) ...<Widget>[
            Gap(18.fx),
            AppPrimaryButton(
              label: action,
              outlined: true,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
