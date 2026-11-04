import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';

/// Why the journey cannot be recorded, why location is needed, and the one
/// button that helps: the system prompt while the system still shows one,
/// else the settings. Nothing is asked until that tap.
class TrackingAccess extends StatelessWidget {
  const TrackingAccess({
    required this.access,
    required this.onAllow,
    required this.onSettings,
    super.key,
  });

  final LocationAccess access;
  final VoidCallback onAllow;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final String key = switch (access) {
      LocationAccess.granted || LocationAccess.denied => 'denied',
      LocationAccess.deniedForever => 'deniedForever',
      LocationAccess.approximate => 'approximate',
      LocationAccess.serviceOff => 'serviceOff',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.tr('journeys.tracking.needs.$key.title'),
          style: context.texts.titleSmall?.copyWith(
            color: context.appColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(8.fx),
        Text(
          context.tr('journeys.tracking.needs.$key.body'),
          style: context.texts.bodySmall?.copyWith(
            color: context.appColors.textMuted,
            height: 1.6,
          ),
        ),
        Gap(16.fx),
        AppPrimaryButton(
          label: context.tr('journeys.tracking.needs.$key.action'),
          outlined: key != 'denied',
          onPressed: key == 'denied' ? onAllow : onSettings,
        ),
      ],
    );
  }
}
