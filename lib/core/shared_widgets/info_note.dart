import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A quiet line with an info glyph: what SafeRide does *not* do — under
/// every planning screen and on the safety screens.
class InfoNote extends StatelessWidget {
  const InfoNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.appColors.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 18.fx, color: muted),
        Gap(8.fx),
        Expanded(
          child: Text(
            text,
            style: context.texts.bodySmall?.copyWith(color: muted, height: 1.6),
          ),
        ),
      ],
    );
  }
}
