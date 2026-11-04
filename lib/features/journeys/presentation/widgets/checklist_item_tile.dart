import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One point of the pre-journey checklist, confirmed with a tap anywhere on
/// the row. Its state is shown three ways, never by colour alone: a primary
/// border on a tinted fill, a ticked box in place of the empty one, and
/// `checked` in the semantics. [onTap] null locks the row (while saving).
class ChecklistItemTile extends StatelessWidget {
  const ChecklistItemTile({
    required this.label,
    required this.confirmed,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool confirmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Semantics(
      container: true,
      checked: confirmed,
      enabled: onTap != null,
      child: Material(
        color: confirmed ? colors.tint(colors.primary) : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.fx),
          side: BorderSide(
            color: confirmed ? colors.primary : colors.border,
            width: confirmed ? 1.5.fx : 1.fx,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(56.fx, kMinInteractiveDimension),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: 14.fx,
                vertical: 12.fx,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    confirmed
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 24.fx,
                    color: confirmed ? colors.primary : colors.textMuted,
                  ),
                  Gap(12.fx),
                  Expanded(
                    child: Text(
                      label,
                      style: context.texts.bodyMedium?.copyWith(
                        color: colors.text,
                        height: 1.5,
                      ),
                    ),
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
