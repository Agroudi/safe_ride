import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// A round button floating on a map, with its name for a screen reader.
class MapButton extends StatelessWidget {
  const MapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Drawn in the accent colour: the thing it does is on.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Semantics(
      container: true,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: colors.surface,
            elevation: 3,
            shadowColor: colors.text.withValues(alpha: 0.2),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: math.max(44, 46.fx),
                height: math.max(44, 46.fx),
                child: Icon(
                  icon,
                  size: 22,
                  color: active ? colors.accentText : colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
