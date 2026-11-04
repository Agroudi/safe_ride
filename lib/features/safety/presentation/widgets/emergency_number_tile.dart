import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One official number: what it is for, a line on when to use it, the
/// number large, and Call — which only opens the phone app with the number
/// ready. [highlighted] marks the general number; [note] says where it
/// applies; [caution] marks a number to confirm locally.
class EmergencyNumberTile extends StatelessWidget {
  const EmergencyNumberTile({
    required this.service,
    required this.description,
    required this.number,
    required this.callLabel,
    required this.onCall,
    this.highlighted = false,
    this.note,
    this.caution,
    super.key,
  });

  final String service;
  final String description;
  final String number;
  final String callLabel;
  final VoidCallback onCall;
  final bool highlighted;
  final String? note;
  final String? caution;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle? small = context.texts.bodySmall?.copyWith(
      color: colors.textMuted,
      height: 1.5,
    );

    // One node per number for a screen reader: its words together, its
    // Call button a target of its own — not merged with the next tile.
    return Semantics(
      container: true,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(16.fx, 14.fx, 12.fx, 14.fx),
        decoration: BoxDecoration(
          color: highlighted ? colors.tint(colors.error) : colors.surface,
          borderRadius: BorderRadius.circular(18.fx),
          border: Border.all(color: highlighted ? colors.error : colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          service,
                          style: context.texts.titleSmall?.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Gap(2.fx),
                        // Digits as dialled, left to right in both languages.
                        Text(
                          number,
                          textDirection: TextDirection.ltr,
                          style: context.texts.headlineSmall?.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(8.fx),
                FilledButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded),
                  label: Text(callLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: highlighted
                        ? colors.error
                        : colors.primary,
                    foregroundColor: highlighted
                        ? colors.onStatus
                        : colors.onPrimary,
                    minimumSize: Size(0, 48.fx),
                  ),
                ),
              ],
            ),
            Gap(6.fx),
            Text(description, style: small),
            if (note case final String line) ...<Widget>[
              Gap(4.fx),
              Text(line, style: small?.copyWith(color: colors.text)),
            ],
            if (caution case final String line) ...<Widget>[
              Gap(6.fx),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16.fx,
                    color: colors.warning,
                  ),
                  Gap(6.fx),
                  Expanded(
                    child: Text(
                      line,
                      style: small?.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
