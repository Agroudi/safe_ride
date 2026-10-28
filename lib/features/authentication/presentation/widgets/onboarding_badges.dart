import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The step's glyph on the brand gradient, at the centre of
/// `OnboardingIllustration` — the pairing `AppLogo` uses, but round, so the
/// rings around it stay concentric.
///
/// The gradient is physical, topLeft → bottomRight: the seal's light, never
/// mirrored, so the seal looks the same in both languages from the splash to
/// this badge. A [shadow] 0..1 scales the glow under it, so the badge the seal
/// lands on casts its shadow only once it has landed.
class OnboardingBadge extends StatelessWidget {
  const OnboardingBadge({required this.icon, super.key, this.shadow});

  /// Raw design size, converted with `.fx`.
  static const double size = 104;

  final IconData icon;

  /// The glow's strength, 0..1; a full glow when null.
  final Animation<double>? shadow;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? shadow = this.shadow;
    if (shadow == null) return _Disc(icon: icon, shadow: 1);
    return AnimatedBuilder(
      animation: shadow,
      builder: (BuildContext context, _) =>
          _Disc(icon: icon, shadow: shadow.value),
    );
  }
}

/// The badge itself, its glow at [shadow] of full strength.
class _Disc extends StatelessWidget {
  const _Disc({required this.icon, required this.shadow});

  final IconData icon;
  final double shadow;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      width: OnboardingBadge.size.fx,
      height: OnboardingBadge.size.fx,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Physical, not start/end, as on `AppLogo`: the brand never mirrors.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.primary, colors.secondary],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            // As under the primary button: a strong glow is muddy on dark.
            color: colors.primary.withValues(
              alpha: (context.isDark ? 0.2 : 0.35) * shadow,
            ),
            offset: Offset(0, 12.fx),
            blurRadius: 28.fx,
            spreadRadius: -8.fx,
          ),
        ],
      ),
      child: Icon(icon, size: 48.fx, color: colors.onPrimary),
    );
  }
}

/// One accent icon on a small surface chip, riding the outer ring of
/// `OnboardingIllustration`.
class OnboardingAccent extends StatelessWidget {
  const OnboardingAccent({required this.icon, required this.color, super.key});

  /// Raw design size, converted with `.fx`. The illustration places the chip
  /// from it, so change both together.
  static const double size = 44;

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      width: size.fx,
      height: size.fx,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface,
        border: Border.all(color: colors.border, width: 1.fx),
      ),
      child: Icon(icon, size: 22.fx, color: color),
    );
  }
}
