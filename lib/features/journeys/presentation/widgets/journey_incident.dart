import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/features/journeys/data/models/potential_incident.dart';
import 'package:safe_ride/features/journeys/logic/cubit/incident_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/incident_banner.dart';

/// The journey's open potential incident, if any, above its recording —
/// nothing at all otherwise.
class JourneyIncident extends StatelessWidget {
  const JourneyIncident({required this.journeyId, super.key});

  final String journeyId;

  @override
  Widget build(BuildContext context) => BlocProvider<IncidentCubit>(
    create: (_) => sl<IncidentCubit>()..watch(journeyId),
    child: BlocBuilder<IncidentCubit, IncidentState>(
      builder: (BuildContext context, IncidentState state) {
        final PotentialIncident? incident = state.incident;
        if (incident == null) return const SizedBox.shrink();
        final String minutes = LocaleNumbers.decimal(
          context.locale.languageCode,
        ).format(((incident.durationSeconds ?? 0) / 60).floor());
        return Padding(
          padding: EdgeInsetsDirectional.only(bottom: 20.fx),
          child: IncidentBanner(
            title: context.tr('journeys.incident.title'),
            body: context.tr(
              'journeys.incident.${incident.type.name}',
              namedArgs: <String, String>{'minutes': minutes},
            ),
            note: context.tr('journeys.incident.note'),
            dismissLabel: context.tr('journeys.incident.dismiss'),
            onDismiss: context.read<IncidentCubit>().dismiss,
          ),
        );
      },
    ),
  );
}
