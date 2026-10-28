import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/point_list.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';

/// What SafeRide is, exactly what it keeps on this phone, and what this
/// version does not do. Plain facts about the app — not a legal privacy
/// policy or terms, which do not exist yet and are not linked.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
            TitleBar(title: context.tr('about.title')),
            Gap(16.fx),
            Text(
              context.tr('about.intro'),
              style: context.texts.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
                height: 1.6,
              ),
            ),
            Gap(20.fx),
            PointList(
              title: context.tr('about.stored.title'),
              icon: Icons.check_circle_outline_rounded,
              color: context.appColors.accentText,
              points: <String>[
                for (final String k in <String>[
                  'account',
                  'journeys',
                  'contacts',
                  'preferences',
                ])
                  context.tr('about.stored.$k'),
              ],
            ),
            Gap(14.fx),
            PointList(
              title: context.tr('about.notYet.title'),
              icon: Icons.remove_circle_outline_rounded,
              color: context.appColors.textMuted,
              points: <String>[
                for (final String k in <String>['online', 'tracking', 'alerts'])
                  context.tr('about.notYet.$k'),
              ],
            ),
            Gap(18.fx),
            InfoNote(text: context.tr('about.deviceNote')),
          ],
        ),
      ),
    );
  }
}
