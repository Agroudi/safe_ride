import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// A calm note that SafeRide noticed unusual movement — never "an
/// accident" — with what it noticed, that nothing was sent, and a way to
/// say all is well. On the info colour, not the error one, and silent: it
/// is a line on the screen, not a notification.
class IncidentBanner extends StatelessWidget {
  const IncidentBanner({
    required this.title,
    required this.body,
    required this.note,
    required this.dismissLabel,
    required this.onDismiss,
    super.key,
  });

  final String title;
  final String body;
  final String note;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle? small = context.texts.bodySmall?.copyWith(
      color: colors.text,
      height: 1.6,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(16.fx),
        decoration: BoxDecoration(
          color: colors.tint(colors.info),
          borderRadius: BorderRadius.circular(18.fx),
          border: Border.all(color: colors.info),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 20.fx,
                  color: colors.text,
                ),
                Gap(10.fx),
                Expanded(
                  child: Text(
                    title,
                    style: context.texts.titleSmall?.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Gap(8.fx),
            Text(body, style: small),
            Gap(6.fx),
            Text(note, style: small?.copyWith(color: colors.textMuted)),
            Gap(14.fx),
            AppPrimaryButton(
              label: dismissLabel,
              outlined: true,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
