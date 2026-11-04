import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Which country's numbers these are — the one the user says they are in —
/// and Change. With no country yet, why SafeRide asks, and Choose.
class EmergencyCountryHeader extends StatelessWidget {
  const EmergencyCountryHeader({
    required this.country,
    required this.onChange,
    super.key,
  });

  final Country? country;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Country? c = country;

    return Container(
      padding: EdgeInsets.all(16.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: colors.border),
      ),
      child: c == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.tr('safety.emergency.choose.title'),
                  style: context.texts.titleSmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(6.fx),
                Text(
                  context.tr('safety.emergency.choose.body'),
                  style: context.texts.bodySmall?.copyWith(
                    color: colors.textMuted,
                    height: 1.6,
                  ),
                ),
                Gap(14.fx),
                AppPrimaryButton(
                  label: context.tr('safety.emergency.choose.action'),
                  onPressed: onChange,
                ),
              ],
            )
          : Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Text(c.flag, style: TextStyle(fontSize: 30.fx)),
                ),
                Gap(12.fx),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.tr('safety.emergency.youAreIn'),
                          style: context.texts.labelSmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          c.name(context.locale.languageCode),
                          style: context.texts.titleMedium?.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onChange,
                  child: Text(context.tr('safety.emergency.change')),
                ),
              ],
            ),
    );
  }
}
