import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The rounded square carrying a `PreferenceOption`'s glyph — an icon, or
/// an emoji such as a country's flag — on the leading edge of the row.
class PreferenceOptionBadge extends StatelessWidget {
  const PreferenceOptionBadge({this.icon, this.emoji, super.key})
    : assert(icon != null || emoji != null, 'an icon or an emoji');

  final IconData? icon;
  final String? emoji;

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
      child: emoji == null
          ? Icon(icon, size: 20.fx, color: colors.secondary)
          // A flag is a picture: not read out (the row says the name).
          : ExcludeSemantics(
              child: Text(emoji!, style: TextStyle(fontSize: 20.fx)),
            ),
    );
  }
}
