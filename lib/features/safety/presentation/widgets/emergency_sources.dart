import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';

/// Where the numbers come from, and when they were last checked: each
/// source's publisher and its address.
class EmergencySources extends StatelessWidget {
  const EmergencySources({required this.country, super.key});

  final EmergencyCountry country;

  @override
  Widget build(BuildContext context) {
    final String language = context.locale.languageCode;
    final TextStyle? quiet = context.texts.bodySmall?.copyWith(
      color: context.appColors.textMuted,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.tr(
            'safety.emergency.checked',
            namedArgs: <String, String>{
              'date': DateFormat.yMMMd(
                LocaleNumbers.tag(language),
              ).format(country.checkedOn),
            },
          ),
          style: context.texts.labelMedium?.copyWith(
            color: context.appColors.text,
          ),
        ),
        Gap(6.fx),
        for (final EmergencySource s in country.sources) ...<Widget>[
          Text(s.publisher.of(language), style: quiet),
          // An address reads left to right in both languages.
          Text(
            s.url.host,
            textDirection: TextDirection.ltr,
            style: quiet?.copyWith(fontSize: 11.fsp),
          ),
          Gap(6.fx),
        ],
      ],
    );
  }
}
