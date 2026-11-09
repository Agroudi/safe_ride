import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';

/// Call and Message for one saved contact — or, when the number cannot be
/// used, why not. A screen reader hears each button with the person's name
/// ("Call Mona", "Text Mona"); both wait while an app is opening ([busy]).
/// They only open the user's own phone or messaging app.
class ContactReachButtons extends StatelessWidget {
  const ContactReachButtons({
    required this.name,
    required this.reach,
    required this.onCall,
    required this.onMessage,
    this.busy = false,
    super.key,
  });

  final String name;
  final ContactReach reach;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    if (reach != ContactReach.available) {
      return Text(
        context.tr('safety.reach.${reach.name}'),
        style: context.texts.bodySmall?.copyWith(color: colors.textMuted),
      );
    }
    final ButtonStyle style = TextButton.styleFrom(
      foregroundColor: colors.accentText,
      minimumSize: Size(0, 44.fx),
    );
    return Wrap(
      spacing: 8.fx,
      children: <Widget>[
        TextButton.icon(
          onPressed: busy ? null : onCall,
          icon: Icon(Icons.call_rounded, size: 18.fx),
          label: Text(
            context.tr('safety.reach.call'),
            semanticsLabel: context.tr(
              'safety.reach.callLabel',
              namedArgs: <String, String>{'name': name},
            ),
          ),
          style: style,
        ),
        TextButton.icon(
          onPressed: busy ? null : onMessage,
          icon: Icon(Icons.sms_rounded, size: 18.fx),
          label: Text(
            context.tr('safety.reach.message'),
            semanticsLabel: context.tr(
              'safety.reach.messageLabel',
              namedArgs: <String, String>{'name': name},
            ),
          ),
          style: style,
        ),
      ],
    );
  }
}
