import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/preference_option_badge.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One choice in a pick-one list — a language, a theme.
///
/// The choice is shown three ways, never by colour alone: a primary border on
/// a tinted fill, a check in place of the empty ring, and `selected` in the
/// semantics, so a screen reader says which one is on. The whole row is the
/// tap target, and the label wraps instead of truncating — a long translation
/// or a large text size makes the row taller, never cut.
class PreferenceOption extends StatelessWidget {
  const PreferenceOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
    this.subtitle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Drawn in a small tinted badge on the leading edge. Optional: a language
  /// written in its own script needs no picture beside it.
  final IconData? icon;

  /// A quieter second line under [label].
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    // A container of its own, so the label, the state and the tap action are
    // one announcement instead of merging into the list around it.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.tint(colors.primary) : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.fx),
          side: BorderSide(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.5.fx : 1.fx,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // The design height, floored at the accessibility minimum in
            // logical pixels: `.fx` shrinks it below 48 on a short phone.
            constraints: BoxConstraints(
              minHeight: math.max(56.fx, kMinInteractiveDimension),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: 14.fx,
                vertical: 10.fx,
              ),
              child: Row(
                children: <Widget>[
                  if (icon case final IconData glyph) ...<Widget>[
                    PreferenceOptionBadge(icon: glyph),
                    Gap(12.fx),
                  ],
                  Expanded(
                    child: _Labels(
                      label: label,
                      subtitle: subtitle,
                      selected: selected,
                    ),
                  ),
                  Gap(12.fx),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22.fx,
                    color: selected ? colors.primary : colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The label, and the optional line under it.
class _Labels extends StatelessWidget {
  const _Labels({required this.label, required this.selected, this.subtitle});

  final String label;
  final String? subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: context.texts.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.appColors.text,
          ),
        ),
        if (subtitle case final String line) ...<Widget>[
          Gap(2.fx),
          Text(
            line,
            // ⚠️ `textMuted` is under 4.5:1 on the light selected tint, so a
            // selected row draws its second line in full `text`.
            style: context.texts.bodySmall?.copyWith(
              color: selected
                  ? context.appColors.text
                  : context.appColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
