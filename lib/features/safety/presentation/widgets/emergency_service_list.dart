import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_number_tile.dart';

/// A country's numbers, one tile each. A number shared by several services
/// is one tile naming them all; the general (or shared) number is marked.
class EmergencyServiceList extends StatelessWidget {
  const EmergencyServiceList({
    required this.country,
    required this.onCall,
    super.key,
  });

  final EmergencyCountry country;
  final ValueChanged<String> onCall;

  /// What a tile is called: the service, or — for a number shared by
  /// several — "Emergency".
  static String title(
    BuildContext context,
    List<EmergencyServiceType> types,
  ) => context.tr(
    'safety.emergency.services.${types.length == 1 ? types.single.name : 'general'}',
  );

  /// When to call: the service's own line, or — for a shared number —
  /// "One number for police, ambulance and fire" («الشرطة والإسعاف
  /// والإطفاء»: Arabic repeats «و» before each one).
  static String description(
    BuildContext context,
    List<EmergencyServiceType> types,
  ) {
    if (types.length == 1) {
      return context.tr('safety.emergency.about.${types.single.name}');
    }
    final List<String> names = <String>[
      for (final EmergencyServiceType t in types)
        context.tr('safety.emergency.inline.${t.name}'),
    ];
    return context.tr(
      'safety.emergency.about.shared',
      namedArgs: <String, String>{
        'list': context.tr(
          'safety.emergency.joined',
          namedArgs: <String, String>{
            'list': names
                .sublist(0, names.length - 1)
                .join(context.locale.languageCode == 'ar' ? ' و' : ', '),
            'last': names.last,
          },
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String language = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final EmergencyService s in country.services) ...<Widget>[
          EmergencyNumberTile(
            service: title(context, s.types),
            description: description(context, s.types),
            number: s.number,
            callLabel: context.tr('safety.emergency.call'),
            highlighted:
                s.types.contains(EmergencyServiceType.general) ||
                s.types.length > 1,
            note: s.note?.of(language),
            caution: s.verification == Verification.secondary
                ? context.tr('safety.emergency.secondary')
                : null,
            onCall: () => onCall(s.number),
          ),
          Gap(10.fx),
        ],
      ],
    );
  }
}
