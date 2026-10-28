import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/emergency_number.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_number_tile.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';
import 'package:url_launcher/url_launcher.dart';

/// Saudi Arabia's official emergency numbers ([EmergencyNumber.saudiArabia]),
/// where 911 applies, and where the list came from. Call only opens the
/// phone app with the number ready — nothing dials by itself, and nobody is
/// alerted.
class EmergencyInfoPage extends StatelessWidget {
  const EmergencyInfoPage({super.key});

  Future<void> _call(BuildContext context, String number) async {
    bool opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: number));
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      sl<AppNotifier>().show(SafetyNotices.callFailed(context, number));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String checked = DateFormat.yMMMd(
      LocaleNumbers.tag(context.locale.languageCode),
    ).format(EmergencyNumber.checkedOn);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            28.fx,
          ),
          children: <Widget>[
            TitleBar(title: context.tr('safety.emergency.title')),
            Gap(16.fx),
            Text(
              context.tr('safety.emergency.country'),
              style: context.texts.titleMedium,
            ),
            Gap(6.fx),
            Text(
              context.tr('safety.emergency.unifiedNote'),
              style: context.texts.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
                height: 1.6,
              ),
            ),
            Gap(18.fx),
            for (final EmergencyNumber e
                in EmergencyNumber.saudiArabia) ...<Widget>[
              EmergencyNumberTile(
                service: context.tr('safety.emergency.services.${e.service}'),
                number: e.number,
                callLabel: context.tr('safety.emergency.call'),
                highlighted: e.service == 'unified',
                onCall: () => _call(context, e.number),
              ),
              Gap(10.fx),
            ],
            Gap(10.fx),
            InfoNote(text: context.tr('safety.emergency.callNote')),
            Gap(12.fx),
            InfoNote(text: context.tr('safety.emergency.outside')),
            Gap(12.fx),
            InfoNote(
              text: context.tr(
                'safety.emergency.sources',
                namedArgs: <String, String>{'date': checked},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
