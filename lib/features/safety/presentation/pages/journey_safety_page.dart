import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/core/shared_widgets/point_list.dart';

/// What SafeRide does with a journey today, and — just as plainly — what it
/// does not do yet, with the two journey actions that do work.
class JourneySafetyPage extends StatelessWidget {
  const JourneySafetyPage({super.key});

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
            TitleBar(title: context.tr('safety.journeys.title')),
            Gap(16.fx),
            Text(
              context.tr('safety.journeys.intro'),
              style: context.texts.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
                height: 1.6,
              ),
            ),
            Gap(20.fx),
            PointList(
              title: context.tr('safety.journeys.can.title'),
              icon: Icons.check_circle_outline_rounded,
              color: context.appColors.accentText,
              points: <String>[
                for (final String k in <String>['plan', 'review', 'status'])
                  context.tr('safety.journeys.can.$k'),
              ],
            ),
            Gap(14.fx),
            PointList(
              title: context.tr('safety.journeys.cannot.title'),
              icon: Icons.remove_circle_outline_rounded,
              color: context.appColors.textMuted,
              points: <String>[
                for (final String k in <String>[
                  'tracking',
                  'sharing',
                  'alerts',
                ])
                  context.tr('safety.journeys.cannot.$k'),
              ],
            ),
            Gap(24.fx),
            AppPrimaryButton(
              label: context.tr('safety.journeys.plan'),
              onPressed: () => context.pushNamed(AppRoutes.planJourney),
            ),
            Gap(12.fx),
            AppPrimaryButton(
              label: context.tr('safety.journeys.history'),
              outlined: true,
              onPressed: () => context.goNamed(AppRoutes.myJourneys),
            ),
          ],
        ),
      ),
    );
  }
}
