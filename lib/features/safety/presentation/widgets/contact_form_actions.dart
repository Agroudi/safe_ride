import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';

/// The contact form's buttons: save, and — when a contact is being edited
/// ([onDelete] set) — delete, in the error colour. Delete waits while a save
/// runs.
class ContactFormActions extends StatelessWidget {
  const ContactFormActions({
    required this.saveLabel,
    required this.deleteLabel,
    required this.busy,
    required this.onSave,
    this.onDelete,
    super.key,
  });

  final String saveLabel;
  final String deleteLabel;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? delete = onDelete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPrimaryButton(label: saveLabel, busy: busy, onPressed: onSave),
        if (delete != null) ...<Widget>[
          Gap(12.fx),
          AppPrimaryButton(
            label: deleteLabel,
            outlined: true,
            color: context.appColors.error,
            onPressed: busy ? null : delete,
          ),
        ],
      ],
    );
  }
}
