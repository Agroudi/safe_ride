import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// A way into another screen: icon, name, one line, and a chevron that
/// follows the reading direction. Use it only for a screen that works.
class LinkTile extends StatelessWidget {
  const LinkTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.fx),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.fx),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46.fx,
                  height: 46.fx,
                  decoration: BoxDecoration(
                    color: colors.tint(colors.secondary),
                    borderRadius: BorderRadius.circular(14.fx),
                  ),
                  child: Icon(icon, size: 24.fx, color: colors.accentText),
                ),
                Gap(14.fx),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3.fx,
                    children: <Widget>[
                      Text(
                        title,
                        style: context.texts.titleSmall?.copyWith(
                          color: colors.text,
                        ),
                      ),
                      Text(
                        body,
                        style: context.texts.bodySmall?.copyWith(
                          color: colors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(8.fx),
                // `chevron_right` mirrors itself in RTL (matchTextDirection).
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
