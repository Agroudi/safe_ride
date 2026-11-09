import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_location_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/location_reading_lines.dart';

/// "Where you are", for the user to read out or copy: the latest reading and
/// its age, the journey in progress, and a new reading on a tap. Nothing on it
/// is sent anywhere, and it says so. Reads [EmergencyLocationCubit].
class EmergencyLocationCard extends StatelessWidget {
  const EmergencyLocationCard({super.key});

  Future<void> _copy(BuildContext context, PositionReading reading) async {
    await Clipboard.setData(
      ClipboardData(text: LocationReadingLines.coordinates(reading)),
    );
    if (context.mounted) {
      sl<AppNotifier>().show(
        AppNotification.success(title: context.tr('safety.location.copied')),
      );
    }
  }

  /// Why there is no reading, when there is none.
  static String _absent(EmergencyLocationState state) {
    if (state.notFound) return 'safety.location.notFound';
    return switch (state.position?.access) {
      PositionAccess.notAllowed => 'safety.location.notAllowed',
      PositionAccess.servicesOff => 'safety.location.servicesOff',
      _ => 'safety.location.none',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return BlocBuilder<EmergencyLocationCubit, EmergencyLocationState>(
      builder: (BuildContext context, EmergencyLocationState state) {
        final EmergencyLocationCubit cubit = context
            .read<EmergencyLocationCubit>();
        final PositionReading? reading = state.reading;
        final PositionAccess? access = state.position?.access;
        final bool readable =
            access == PositionAccess.allowed ||
            access == PositionAccess.approximate;
        final String? destination = state.position?.destination;
        final TextStyle? body = context.texts.bodyMedium?.copyWith(
          color: colors.text,
        );

        return Container(
          padding: EdgeInsets.all(16.fx),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18.fx),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (state.loading)
                const Center(child: CircularProgressIndicator())
              else if (reading != null)
                LocationReadingLines(reading: reading, now: state.now)
              else
                Text(context.tr(_absent(state)), style: body),
              if (access == PositionAccess.approximate) ...<Widget>[
                Gap(6.fx),
                Text(context.tr('safety.location.approximate'), style: body),
              ],
              if (destination != null) ...<Widget>[
                Gap(10.fx),
                Text(
                  context.tr(
                    'safety.location.journey',
                    namedArgs: <String, String>{
                      // First-strong isolate: a place may be in either script.
                      'destination':
                          '${String.fromCharCode(0x2068)}$destination'
                          '${String.fromCharCode(0x2069)}',
                    },
                  ),
                  style: body,
                ),
              ],
              Gap(14.fx),
              AppPrimaryButton(
                label: context.tr(
                  reading == null
                      ? 'safety.location.find'
                      : 'safety.location.update',
                ),
                outlined: true,
                busy: state.locating,
                onPressed: readable ? cubit.locate : null,
              ),
              if (reading != null) ...<Widget>[
                Gap(4.fx),
                TextButton.icon(
                  onPressed: () => _copy(context, reading),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(context.tr('safety.location.copy')),
                ),
              ],
              Gap(10.fx),
              InfoNote(text: context.tr('safety.location.note')),
            ],
          ),
        );
      },
    );
  }
}
