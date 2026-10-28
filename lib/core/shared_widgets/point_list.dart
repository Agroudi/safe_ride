import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// A titled card of short points, each behind the same glyph — the Safety
/// Guide, Journey Safety and About.
class PointList extends StatelessWidget {
  const PointList({
    required this.title,
    required this.points,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final List<String> points;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(16.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: context.texts.titleSmall?.copyWith(color: colors.text),
            ),
          ),
          for (final String point in points) ...<Widget>[
            Gap(12.fx),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: 2.fx),
                  child: Icon(icon, size: 18.fx, color: color),
                ),
                Gap(10.fx),
                Expanded(
                  child: Text(
                    point,
                    style: context.texts.bodyMedium?.copyWith(
                      color: colors.text,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
