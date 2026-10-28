import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_assets.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/directional_svg.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The rounded chevron tile that returns to the previous screen. It sits on the
/// leading edge, so it lands on the right in Arabic and on the left in English.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  /// Null pops the current route — the right default almost everywhere.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    // A bare chevron says nothing to a screen reader. Material's own tooltip
    // is already translated for every locale the app ships, so no key is
    // needed.
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: 42.fx,
          height: 42.fx,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(30.fx),
            border: Border.all(color: colors.border, width: 1.fx),
          ),
          child: DirectionalSvg(
            AppAssets.chevronLeft,
            width: 19.fx,
            height: 19.fx,
            // The asset's stroke is baked in; recolour it per theme.
            colorFilter: ColorFilter.mode(colors.text, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
