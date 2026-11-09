import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';

/// Opens a journey's map: live while it runs, what was recorded after.
class JourneyMapButton extends StatelessWidget {
  const JourneyMapButton({required this.journey, super.key});

  final JourneyModel journey;

  @override
  Widget build(BuildContext context) => AppPrimaryButton(
    label: context.tr(
      journey.status == JourneyStatus.active
          ? 'journeys.map.open'
          : 'journeys.map.openRecorded',
    ),
    outlined: true,
    onPressed: () => context.pushNamed(
      AppRoutes.journeyMap,
      pathParameters: <String, String>{'id': journey.id},
    ),
  );
}
