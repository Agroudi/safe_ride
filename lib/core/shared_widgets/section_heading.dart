import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A section's title, a heading for screen readers, with an optional
/// trailing link ("See all").
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String? action = actionLabel;

    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: context.texts.titleMedium?.copyWith(
                color: context.appColors.text,
              ),
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.accentText,
              minimumSize: Size(0, 44.fx),
              textStyle: context.texts.labelLarge,
            ),
            child: Text(action),
          ),
      ],
    );
  }
}
