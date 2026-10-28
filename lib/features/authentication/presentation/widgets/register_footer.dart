import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_link_button.dart';

/// Under the register button: where the account lives (this phone only —
/// never a claim of a server), then the way to login.
class RegisterFooter extends StatelessWidget {
  const RegisterFooter({super.key, this.onLogin});

  /// Null while a registration is running.
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Column(
      children: <Widget>[
        Text(
          context.tr('auth.register.deviceOnly'),
          textAlign: TextAlign.center,
          style: context.texts.bodySmall?.copyWith(color: colors.textMuted),
        ),
        Gap(14.fx),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4.fx,
          children: <Widget>[
            Text(
              context.tr('auth.register.haveAccount'),
              style: context.texts.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
            AuthLinkButton(
              label: context.tr('auth.register.login'),
              onPressed: onLogin,
              style: context.texts.labelMedium?.copyWith(
                fontSize: 14.fsp,
                color: colors.accentText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
