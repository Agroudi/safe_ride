import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:safe_ride/core/constants/app_assets.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// The eye at the end edge of a password field. The design only draws the
/// hidden state, so the revealed one falls back to the Material glyph.
class PasswordEye extends StatelessWidget {
  const PasswordEye({
    required this.obscured,
    required this.onPressed,
    super.key,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color tone = context.appColors.textMuted;

    return Semantics(
      container: true,
      button: true,
      label: context.tr(
        obscured ? 'validation.showPassword' : 'validation.hidePassword',
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 10.fx,
            end: 16.fx,
            top: 12.fx,
            bottom: 12.fx,
          ),
          child: obscured
              ? SvgPicture.asset(
                  AppAssets.eyeOff,
                  width: 21.fx,
                  height: 19.fx,
                  colorFilter: ColorFilter.mode(tone, BlendMode.srcIn),
                )
              : Icon(Icons.visibility_outlined, size: 21.fx, color: tone),
        ),
      ),
    );
  }
}
