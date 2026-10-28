import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/password_strength_bar.dart';

/// Registration's five fields, inside the page's `Form`: full name, email,
/// an optional (never verified) mobile number, the password with its policy
/// and strength bar, and the confirmation. Locked while [enabled] is false;
/// [emailError] is the repository's verdict ("already exists").
class RegisterFields extends StatelessWidget {
  const RegisterFields({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirm,
    required this.enabled,
    required this.onSubmit,
    required this.onEmailChanged,
    this.emailError,
    super.key,
  });

  final TextEditingController fullName;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onEmailChanged;
  final String? emailError;

  @override
  Widget build(BuildContext context) {
    final Validators validate = Validators.of(context);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14.fx,
        children: <Widget>[
          AppTextField(
            label: context.tr('auth.register.fullNameLabel'),
            hint: context.tr('auth.register.fullNameHint'),
            controller: fullName,
            validator: validate.fullName,
            enabled: enabled,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
          ),
          AppTextField(
            label: context.tr('auth.register.emailLabel'),
            hint: context.tr('auth.register.emailHint'),
            controller: email,
            validator: validate.email,
            errorText: emailError,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onEmailChanged(),
            autofillHints: const <String>[AutofillHints.email],
          ),
          AppTextField(
            label: context.tr('auth.register.phoneLabel'),
            hint: context.tr('auth.register.phoneHint'),
            helperText: context.tr('auth.register.phoneNote'),
            controller: phone,
            validator: validate.phone,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                label: context.tr('auth.register.passwordLabel'),
                hint: context.tr('auth.register.passwordHint'),
                helperText: context.tr('auth.register.passwordPolicy'),
                controller: password,
                validator: validate.password,
                enabled: enabled,
                obscurable: true,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
              ),
              Gap(8.fx),
              // The same three rules as the validator: full means accepted.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: password,
                builder: (_, TextEditingValue value, _) => PasswordStrengthBar(
                  score: Validators.passwordScore(value.text),
                ),
              ),
            ],
          ),
          AppTextField(
            label: context.tr('auth.register.confirmPasswordLabel'),
            hint: context.tr('auth.register.confirmPasswordHint'),
            controller: confirm,
            validator: validate.confirm(() => password.text),
            enabled: enabled,
            obscurable: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
        ],
      ),
    );
  }
}
