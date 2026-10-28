import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/core/shared_widgets/point_list.dart';

/// General ride-safety advice, in four sections. The text lives in the
/// translation files, so it is in the app — no connection needed. It is
/// advice, never a claim about what SafeRide does.
class SafetyGuidePage extends StatelessWidget {
  const SafetyGuidePage({super.key});

  /// Each section and how many tips it has in `safety.guide.sections`.
  static const List<(String, int)> _sections = <(String, int)>[
    ('before', 4),
    ('during', 4),
    ('after', 3),
    ('emergency', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            28.fx,
          ),
          children: <Widget>[
            TitleBar(title: context.tr('safety.guide.title')),
            Gap(16.fx),
            Text(
              context.tr('safety.guide.intro'),
              style: context.texts.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
                height: 1.6,
              ),
            ),
            Gap(20.fx),
            for (final (String key, int count) in _sections) ...<Widget>[
              PointList(
                title: context.tr('safety.guide.sections.$key.title'),
                icon: Icons.check_circle_outline_rounded,
                color: context.appColors.accentText,
                points: <String>[
                  for (int i = 1; i <= count; i++)
                    context.tr('safety.guide.sections.$key.tip$i'),
                ],
              ),
              Gap(14.fx),
            ],
          ],
        ),
      ),
    );
  }
}
