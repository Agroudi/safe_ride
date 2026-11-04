import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/country_picker_sheet.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_country_header.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_service_list.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_sources.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_warning.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// The emergency numbers of the country the user says they are in — from
/// the app's own checked dataset, so it works offline. Call only opens the
/// phone app with the number ready: nothing dials by itself, nobody is
/// alerted, and SafeRide never claims a call was made.
class EmergencyInfoPage extends StatelessWidget {
  const EmergencyInfoPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<EmergencyCubit>(
    create: (_) => sl<EmergencyCubit>()..load(),
    child: const _EmergencyView(),
  );
}

class _EmergencyView extends StatelessWidget {
  const _EmergencyView();

  Future<void> _change(BuildContext context, Country? current) async {
    final EmergencyCubit cubit = context.read<EmergencyCubit>();
    final String? code = await showCountryPicker(
      context,
      selected: current?.code,
    );
    if (code != null) await cubit.choose(code);
  }

  Future<void> _call(BuildContext context, String number) async {
    final DialOutcome outcome = await context.read<EmergencyCubit>().dial(
      number,
    );
    if (context.mounted) {
      sl<AppNotifier>().show(SafetyNotices.dial(context, outcome, number));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String language = context.locale.languageCode;

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<EmergencyCubit, EmergencyState>(
          builder: (BuildContext context, EmergencyState state) {
            final Country? country = switch (state) {
              EmergencyReady(:final Country country) ||
              EmergencyUnavailable(:final Country country) => country,
              _ => null,
            };
            return ListView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenSide,
                AppSpacing.screenTop,
                AppSpacing.screenSide,
                28.fx,
              ),
              children: <Widget>[
                TitleBar(title: context.tr('safety.emergency.title')),
                Gap(16.fx),
                EmergencyWarning(text: context.tr('safety.emergency.warning')),
                Gap(14.fx),
                if (state is! EmergencyLoading)
                  EmergencyCountryHeader(
                    country: country,
                    onChange: () => _change(context, country),
                  ),
                Gap(16.fx),
                ...switch (state) {
                  EmergencyReady(:final EmergencyCountry numbers) => <Widget>[
                    if (numbers.note case final LocalizedText note) ...<Widget>[
                      InfoNote(text: note.of(language)),
                      Gap(14.fx),
                    ],
                    EmergencyServiceList(
                      country: numbers,
                      onCall: (String number) => _call(context, number),
                    ),
                    Gap(8.fx),
                    InfoNote(text: context.tr('safety.emergency.callNote')),
                    Gap(16.fx),
                    EmergencySources(country: numbers),
                  ],
                  EmergencyUnavailable(:final Country country) => <Widget>[
                    AppEmptyState(
                      icon: Icons.help_outline_rounded,
                      title: context.tr('safety.emergency.unavailable.title'),
                      body: context.tr(
                        'safety.emergency.unavailable.body',
                        namedArgs: <String, String>{
                          'country': country.name(language),
                        },
                      ),
                    ),
                  ],
                  EmergencyLoading() => <Widget>[
                    const Center(child: CircularProgressIndicator()),
                  ],
                  EmergencyNeedsCountry() => const <Widget>[],
                },
              ],
            );
          },
        ),
      ),
    );
  }
}
