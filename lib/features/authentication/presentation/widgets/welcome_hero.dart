import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_logo.dart';
import 'package:safe_ride/core/shared_widgets/brand_seal.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/halo_rings.dart';

/// The brand moment of the welcome screen: the logo inside soft rings, then
/// the title and the line under it, all centred.
///
/// On arrival the title and subtitle rise in on beats 1 and 2 of the page's
/// `EntranceScope`. The seal never enters: it lands from the splash or home,
/// or appears with the page.
class WelcomeHero extends StatelessWidget {
  const WelcomeHero({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _LogoRings(),
        Gap(28.fx),
        EntranceItem.beat(
          1,
          rise: AppMotion.rise,
          child: Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.headlineMedium?.copyWith(
                color: context.appColors.text,
              ),
            ),
          ),
        ),
        Gap(10.fx),
        EntranceItem.beat(
          2,
          rise: AppMotion.rise,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }
}

/// [AppLogo] centred in three concentric rings — depth without an
/// illustration. They open inner to outer while the seal is still landing,
/// then keep breathing, and the dotted outer orbit keeps turning
/// (`HaloRings`). Only the logo's label is announced.
class _LogoRings extends StatelessWidget {
  const _LogoRings();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Color ring = colors.secondary;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        HaloRings(
          rings: <HaloRing>[
            HaloRing(diameter: 120.fx, fill: colors.tint(ring)),
            HaloRing(
              diameter: 160.fx,
              fill: ring.withValues(alpha: 0.05),
              stroke: ring.withValues(alpha: 0.24),
              strokeWidth: 1.fx,
            ),
            HaloRing(
              diameter: 208.fx,
              stroke: ring.withValues(alpha: 0.36),
              strokeWidth: 1.4.fx,
              dotted: true,
            ),
          ],
        ),
        const BrandSeal(child: AppLogo(size: 88)),
      ],
    );
  }
}
