import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One destination of [AppTabBar].
@immutable
class AppTabItem {
  const AppTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The signed-in bottom bar: a quiet surface strip, the selected tab on a
/// teal wash with its filled icon. Every item leads to a real screen — none
/// is drawn for show. Clears the system navigation bar itself.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.items,
    required this.current,
    required this.onSelected,
    super.key,
  });

  final List<AppTabItem> items;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? colors.surfaceElevated : colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.fx, vertical: 6.fx),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _TabButton(
                    item: items[i],
                    selected: i == current,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color ink = selected ? colors.accentText : colors.textMuted;
    final Duration time = context.reduceMotion
        ? Duration.zero
        : AppDurations.short;

    // `container`: each tab its own node, or the bar reads as one blob.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 56.fx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: time,
                curve: AppCurves.move,
                width: 56.fx,
                height: 30.fx,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.tint(colors.secondary)
                      : colors.tint(colors.secondary).withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(15.fx),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22.fx,
                  color: ink,
                ),
              ),
              Gap(4.fx),
              // A third of the width at 2× text: shrink to fit rather than
              // cut "My Journeys" to "My Journe…". The label is announced in
              // full either way.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: context.texts.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
