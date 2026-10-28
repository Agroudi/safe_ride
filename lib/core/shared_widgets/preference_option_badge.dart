import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The rounded square carrying a `PreferenceOption`'s glyph, on the leading
/// edge of the row.
class PreferenceOptionBadge extends StatelessWidget {
  const PreferenceOptionBadge({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      width: 36.fx,
      height: 36.fx,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.tint(colors.secondary),
        borderRadius: BorderRadius.circular(12.fx),
      ),
      child: Icon(icon, size: 20.fx, color: colors.secondary),
    );
  }
}
