import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/link_tile.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/safety_feature_tile.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';

/// Home's safety features. Trusted Contacts and Safety Resources (the
/// guide and emergency numbers) are built, so they open their screens; Journey
/// Sharing needs an online service, so it stays a *Planned* tile — never a
/// tap that leads nowhere.
class HomeSafetySection extends StatelessWidget {
  const HomeSafetySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(title: context.tr('home.safety.title')),
        Gap(8.fx),
        LinkTile(
          icon: Icons.group_rounded,
          title: context.tr('home.safety.contacts.title'),
          body: context.tr('home.safety.contacts.body'),
          onTap: () => context.pushNamed(AppRoutes.trustedContacts),
        ),
        Gap(10.fx),
        LinkTile(
          icon: Icons.health_and_safety_rounded,
          title: context.tr('home.safety.resources.title'),
          body: context.tr('home.safety.resources.body'),
          onTap: () => context.goNamed(AppRoutes.safety),
        ),
        Gap(10.fx),
        SafetyFeatureTile(
          icon: Icons.share_location_rounded,
          title: context.tr('home.safety.sharing.title'),
          body: context.tr('home.safety.sharing.body'),
          badge: context.tr('home.safety.planned'),
        ),
      ],
    );
  }
}
