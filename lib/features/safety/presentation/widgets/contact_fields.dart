import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/validation/validators.dart';

/// A contact's three fields, inside the page's `Form`: full name, phone
/// number (required), relationship (optional). [phoneError] is the
/// repository's verdict ("already in your contacts").
class ContactFields extends StatelessWidget {
  const ContactFields({
    required this.name,
    required this.phone,
    required this.relationship,
    required this.enabled,
    required this.onPhoneChanged,
    required this.onSubmit,
    this.phoneError,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController relationship;
  final bool enabled;
  final VoidCallback onPhoneChanged;
  final VoidCallback onSubmit;
  final String? phoneError;

  @override
  Widget build(BuildContext context) {
    final Validators validate = Validators.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          label: context.tr('safety.contacts.form.nameLabel'),
          hint: context.tr('safety.contacts.form.nameHint'),
          controller: name,
          validator: validate.fullName,
          enabled: enabled,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
        ),
        Gap(14.fx),
        AppTextField(
          label: context.tr('safety.contacts.form.phoneLabel'),
          hint: context.tr('safety.contacts.form.phoneHint'),
          controller: phone,
          validator: validate.contactPhone,
          errorText: phoneError,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onPhoneChanged(),
        ),
        Gap(14.fx),
        AppTextField(
          label: context.tr('safety.contacts.form.relationshipLabel'),
          hint: context.tr('safety.contacts.form.relationshipHint'),
          controller: relationship,
          validator: validate.relationship,
          enabled: enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
      ],
    );
  }
}
