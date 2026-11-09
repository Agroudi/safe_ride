import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/safety/data/models/emergency_directory.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_number_tile.dart';

/// A country's numbers in the directory's order, one tile each: a number
/// that answers only in some regions first, naming them, then the rest by
/// what happened. A number shared by several services is one tile naming
/// them all.
class EmergencyServiceList extends StatelessWidget {
  const EmergencyServiceList({
    required this.directory,
    required this.onCall,
    super.key,
  });

  final EmergencyDirectory directory;
  final ValueChanged<String> onCall;

  /// What a tile is called: the service, or — for a number shared by
  /// several — "Emergency".
  static String title(
    BuildContext context,
    List<EmergencyServiceType> types,
  ) => context.tr(
    'safety.emergency.services.${types.length == 1 ? types.single.name : 'general'}',
  );

  /// "a, b and c" — Arabic repeats «و» before each one («الشرطة والإسعاف
  /// والإطفاء»).
  static String join(BuildContext context, List<EmergencyServiceType> types) {
    final List<String> names = <String>[
      for (final EmergencyServiceType t in types)
        context.tr('safety.emergency.inline.${t.name}'),
    ];
    if (names.length == 1) return names.single;
    return context.tr(
      'safety.emergency.joined',
      namedArgs: <String, String>{
        'list': names
            .sublist(0, names.length - 1)
            .join(context.locale.languageCode == 'ar' ? ' و' : ', '),
        'last': names.last,
      },
    );
  }

  /// When to call: the service's own line, or — for a shared number —
  /// "One number for ambulance, police and fire".
  static String description(
    BuildContext context,
    List<EmergencyServiceType> types,
  ) => types.length == 1
      ? context.tr('safety.emergency.about.${types.single.name}')
      : context.tr(
          'safety.emergency.about.shared',
          namedArgs: <String, String>{'list': join(context, types)},
        );

  @override
  Widget build(BuildContext context) {
    final String language = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final DirectoryLine line in directory.lines) ...<Widget>[
          EmergencyNumberTile(
            service: title(context, line.types),
            description: description(context, line.types),
            number: line.service.number,
            callLabel: context.tr('safety.emergency.call'),
            highlighted: line.unified,
            note: line.service.note?.of(language),
            caution: line.service.verification == Verification.secondary
                ? context.tr('safety.emergency.secondary')
                : null,
            onCall: () => onCall(line.service.number),
          ),
          Gap(10.fx),
        ],
      ],
    );
  }
}
