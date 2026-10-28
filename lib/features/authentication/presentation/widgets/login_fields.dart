import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/validation/validators.dart';

/// Login's email and password, inside the page's `Form`. Locked while
/// [enabled] is false; [passwordError] is the repository's verdict.
class LoginFields extends StatelessWidget {
  const LoginFields({
    required this.email,
    required this.password,
    required this.enabled,
    required this.onSubmit,
    required this.onPasswordChanged,
    this.passwordError,
    super.key,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onPasswordChanged;
  final String? passwordError;

  @override
  Widget build(BuildContext context) {
    final Validators validate = Validators.of(context);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            label: context.tr('auth.login.emailLabel'),
            hint: context.tr('auth.login.emailHint'),
            controller: email,
            validator: validate.email,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.email],
          ),
          Gap(16.fx),
          // Presence only — the password policy is for creating one, and an
          // old password may predate it.
          AppTextField(
            label: context.tr('auth.login.passwordLabel'),
            hint: context.tr('auth.login.passwordHint'),
            controller: password,
            validator: validate.required,
            errorText: passwordError,
            enabled: enabled,
            obscurable: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onPasswordChanged(),
            onSubmitted: (_) => onSubmit(),
            autofillHints: const <String>[AutofillHints.password],
          ),
        ],
      ),
    );
  }
}
