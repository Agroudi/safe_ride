import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/validation/validators.dart';

/// The edit-profile form's body: full name and the optional phone (the same
/// rules and labels as registration), then the email, read-only.
class ProfileFields extends StatelessWidget {
  const ProfileFields({
    required this.name,
    required this.phone,
    required this.email,
    required this.enabled,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final String email;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final Validators validate = Validators.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          label: context.tr('auth.register.fullNameLabel'),
          controller: name,
          validator: validate.fullName,
          enabled: enabled,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.name],
        ),
        Gap(14.fx),
        AppTextField(
          label: context.tr('auth.register.phoneLabel'),
          hint: context.tr('auth.register.phoneHint'),
          helperText: context.tr('auth.register.phoneNote'),
          controller: phone,
          validator: validate.phone,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          autofillHints: const <String>[AutofillHints.telephoneNumber],
        ),
        Gap(18.fx),
        Text(
          context.tr('profile.editPage.emailLabel'),
          style: context.texts.labelMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        Gap(6.fx),
        // Sized to the address and placed at the reading start: a stretched
        // LTR text would align to its own (left) start in Arabic.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            email,
            textDirection: TextDirection.ltr,
            style: context.texts.bodyMedium,
          ),
        ),
        Gap(8.fx),
        InfoNote(text: context.tr('profile.editPage.emailNote')),
      ],
    );
  }
}
