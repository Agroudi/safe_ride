import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_status_chip.dart';

/// A safety feature that is **not built yet**: icon, name, what it will do,
/// and a "Planned" badge. Deliberately not tappable and not dimmed into
/// unreadability — it says plainly what is missing, and nothing pretends to
/// work. When a feature is built, it gets a destination and an `onTap`.
class SafetyFeatureTile extends StatelessWidget {
  const SafetyFeatureTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return MergeSemantics(
      child: Container(
        padding: EdgeInsets.all(14.fx),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18.fx),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42.fx,
              height: 42.fx,
              decoration: BoxDecoration(
                color: colors.tint(colors.textMuted),
                borderRadius: BorderRadius.circular(14.fx),
              ),
              child: Icon(icon, size: 22.fx, color: colors.textMuted),
            ),
            Gap(12.fx),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: context.texts.titleSmall?.copyWith(
                            color: colors.text,
                          ),
                        ),
                      ),
                      Gap(8.fx),
                      JourneyStatusChip(label: badge, color: colors.textMuted),
                    ],
                  ),
                  Gap(4.fx),
                  Text(
                    body,
                    style: context.texts.bodySmall?.copyWith(
                      color: colors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
