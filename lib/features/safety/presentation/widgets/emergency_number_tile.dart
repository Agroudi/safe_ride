import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One official number: the service, the number large, and Call — which only
/// opens the phone app with the number ready. [highlighted] marks the
/// unified number.
class EmergencyNumberTile extends StatelessWidget {
  const EmergencyNumberTile({
    required this.service,
    required this.number,
    required this.callLabel,
    required this.onCall,
    this.highlighted = false,
    super.key,
  });

  final String service;
  final String number;
  final String callLabel;
  final VoidCallback onCall;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(16.fx, 12.fx, 12.fx, 12.fx),
      decoration: BoxDecoration(
        color: highlighted ? colors.tint(colors.error) : colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: highlighted ? colors.error : colors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    service,
                    style: context.texts.bodyMedium?.copyWith(
                      color: colors.textMuted,
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
          FilledButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded),
            label: Text(callLabel),
            style: FilledButton.styleFrom(
              backgroundColor: highlighted ? colors.error : colors.primary,
              foregroundColor: highlighted ? colors.onStatus : colors.onPrimary,
              minimumSize: Size(0, 48.fx),
            ),
          ),
        ],
      ),
    );
  }
}
