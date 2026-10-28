import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_link_button.dart';

/// The two centred links under the login button: password help, and the
/// way to registration. Disabled (null) while a sign-in is running.
class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key, this.onForgotPassword, this.onCreateAccount});

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Column(
      children: <Widget>[
        AuthLinkButton(
          label: context.tr('auth.login.forgotPassword'),
          onPressed: onForgotPassword,
          style: context.texts.labelMedium?.copyWith(color: colors.accentText),
        ),
        Gap(18.fx),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4.fx,
          children: <Widget>[
            Text(
              context.tr('auth.login.noAccount'),
              style: context.texts.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
            AuthLinkButton(
              label: context.tr('auth.login.createAccount'),
              onPressed: onCreateAccount,
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
