import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/safety/data/models/emergency_directory.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_service_list.dart';

/// The essential services with no checked number of their own, said out
/// loud — never filled in with a guess — and the ambulance number to call
/// instead when someone is hurt or in danger.
class EmergencyMissingNote extends StatelessWidget {
  const EmergencyMissingNote({
    required this.directory,
    required this.country,
    super.key,
  });

  final EmergencyDirectory directory;
  final Country country;

  /// A number read left to right inside Arabic text, as dialled.
  static String ltr(String number) =>
      '${String.fromCharCode(0x2066)}$number${String.fromCharCode(0x2069)}';

  @override
  Widget build(BuildContext context) {
    if (directory.missing.isEmpty) return const SizedBox.shrink();
    final String? number = directory
        .numberFor(EmergencyServiceType.ambulance)
        ?.number;
    final String none = context.tr(
      'safety.emergency.missing.none',
      namedArgs: <String, String>{
        'services': EmergencyServiceList.join(context, directory.missing),
        'country': country.name(context.locale.languageCode),
      },
    );
    final String call = number == null
        ? ''
        : ' ${context.tr('safety.emergency.missing.call', namedArgs: <String, String>{'number': ltr(number)})}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InfoNote(text: '$none$call'),
        Gap(10.fx),
      ],
    );
  }
}
