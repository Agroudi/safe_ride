import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/link_tile.dart';

/// The Safety tab: ways in, each to a working screen — sharing, Trusted
/// Contacts, the Safety Guide, Journey Safety, Emergency Information, and in a build with
/// contact alerts the alerts received and accepting an invite — and a plain
/// line about what SafeRide does not do.
class SafetyCenterPage extends StatelessWidget {
  const SafetyCenterPage({super.key});

  static const List<(String, IconData, String)> _entries =
      <(String, IconData, String)>[
        ('share', Icons.share_location_rounded, AppRoutes.shareLocation),
        ('contacts', Icons.group_rounded, AppRoutes.trustedContacts),
        if (AppFeatures.contactAlerts) ...<(String, IconData, String)>[
          ('alerts', Icons.notifications_rounded, AppRoutes.safetyAlerts),
          ('invite', Icons.person_add_alt_1_rounded, AppRoutes.acceptInvite),
        ],
        ('guide', Icons.menu_book_rounded, AppRoutes.safetyGuide),
        ('journeys', Icons.route_rounded, AppRoutes.journeySafety),
        ('emergency', Icons.emergency_rounded, AppRoutes.emergencyInfo),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            28.fx,
          ),
          children: <Widget>[
            Semantics(
              container: true,
              header: true,
              child: Text(
                context.tr('safety.title'),
                style: context.texts.titleLarge,
              ),
            ),
            Gap(4.fx),
            Text(
              context.tr('safety.subtitle'),
              style: context.texts.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            Gap(20.fx),
            for (final (String key, IconData icon, String route)
                in _entries) ...<Widget>[
              LinkTile(
                icon: icon,
                title: context.tr('safety.entries.$key.title'),
                body: context.tr('safety.entries.$key.body'),
                onTap: () => context.pushNamed(route),
              ),
              Gap(12.fx),
            ],
            Gap(8.fx),
            InfoNote(text: context.tr('safety.note')),
          ],
        ),
      ),
    );
  }
}
