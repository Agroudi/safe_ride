import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/country_picker_sheet.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/safety/data/models/emergency_directory.dart';
import 'package:safe_ride/features/safety/data/models/emergency_services.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_country_header.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_missing_note.dart';
import 'package:safe_ride/features/safety/presentation/widgets/emergency_service_list.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// The emergency directory — the one in the app, on Emergency information
/// and on Get help alike: the country the user chose (and Change), that
/// country's checked numbers by what happened, what is not listed, and what
/// Call does. Reads [EmergencyCubit] from above.
class EmergencyDirectorySection extends StatelessWidget {
  const EmergencyDirectorySection({super.key});

  Future<void> _change(BuildContext context, Country? current) async {
    final EmergencyCubit cubit = context.read<EmergencyCubit>();
    final String? code = await showCountryPicker(
      context,
      selected: current?.code,
    );
    if (code != null) await cubit.choose(code);
  }

  Future<void> _call(BuildContext context, String number) async {
    final DialOutcome? outcome = await context.read<EmergencyCubit>().dial(
      number,
    );
    if (context.mounted) SafetyNotices.showDial(context, outcome, number);
  }

  @override
  Widget build(BuildContext context) {
    final String language = context.locale.languageCode;

    return BlocBuilder<EmergencyCubit, EmergencyState>(
      builder: (BuildContext context, EmergencyState state) {
        final Country? country = switch (state) {
          EmergencyReady(:final Country country) ||
          EmergencyUnavailable(:final Country country) => country,
          _ => null,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (state is! EmergencyLoading) ...<Widget>[
              EmergencyCountryHeader(
                country: country,
                onChange: () => _change(context, country),
              ),
              Gap(16.fx),
            ],
            ...switch (state) {
              EmergencyReady(
                :final Country country,
                :final EmergencyCountry numbers,
              ) =>
                <Widget>[
                  if (numbers.note case final LocalizedText note) ...<Widget>[
                    InfoNote(text: note.of(language)),
                    Gap(14.fx),
                  ],
                  EmergencyServiceList(
                    directory: EmergencyDirectory.of(numbers),
                    onCall: (String number) => _call(context, number),
                  ),
                  EmergencyMissingNote(
                    directory: EmergencyDirectory.of(numbers),
                    country: country,
                  ),
                  InfoNote(text: context.tr('safety.emergency.callNote')),
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
    );
  }
}
