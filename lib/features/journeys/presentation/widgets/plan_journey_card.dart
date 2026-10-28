import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Home's main card: the brand's primary → secondary gradient (the logo
/// tile's, so it is the same physical direction in both languages), a route
/// glyph, the heading, one line, and Start a Journey.
class PlanJourneyCard extends StatelessWidget {
  const PlanJourneyCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onStart,
    super.key,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color ink = colors.onPrimary;

    return Container(
      padding: EdgeInsets.all(20.fx),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.fx),
        // ⚠️ Physical on purpose, like `AppLogo` (CLAUDE.md §16 Brand).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.primary, colors.secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44.fx,
            height: 44.fx,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14.fx),
            ),
            child: Icon(Icons.route_rounded, color: ink, size: 24.fx),
          ),
          Gap(16.fx),
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: context.texts.titleLarge?.copyWith(color: ink),
            ),
          ),
          Gap(6.fx),
          Text(
            body,
            style: context.texts.bodyMedium?.copyWith(
              color: ink.withValues(alpha: 0.88),
              height: 1.6,
            ),
          ),
          Gap(18.fx),
          AppPrimaryButton(
            label: actionLabel,
            color: ink,
            foregroundColor: colors.primary,
            withShadow: false,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
