import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';

/// Asks before a consequential action (signing out). Resolves to true only
/// when [confirmLabel] is tapped — back, a tap outside or [cancelLabel] are
/// all "no". With [destructive] the confirm action is drawn in `error`.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: destructive
                ? context.appColors.error
                : context.appColors.accentText,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
