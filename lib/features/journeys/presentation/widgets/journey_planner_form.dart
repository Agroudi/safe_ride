import 'package:flutter/material.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_form.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_planner.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_pin_button.dart';

/// `JourneyForm` as the planner shows it: a pin button under each place.
class JourneyPlannerForm extends StatelessWidget {
  const JourneyPlannerForm({
    required this.planner,
    required this.originPinned,
    required this.destinationPinned,
    required this.onPick,
    super.key,
  });

  final JourneyPlanner planner;
  final bool originPinned;
  final bool destinationPinned;
  final ValueChanged<MapPlaceKind> onPick;

  @override
  Widget build(BuildContext context) => JourneyForm(
    from: planner.from,
    to: planner.to,
    departsAt: planner.departsAt,
    onDeparture: planner.onDeparture,
    past: planner.past,
    keptDeparture: planner.keptDeparture,
    fromAction: PlacePinButton(
      kind: MapPlaceKind.start,
      pinned: originPinned,
      onPressed: onPick,
    ),
    toAction: PlacePinButton(
      kind: MapPlaceKind.destination,
      pinned: destinationPinned,
      onPressed: onPick,
    ),
  );
}
