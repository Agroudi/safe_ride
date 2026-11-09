import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/logic/cubit/route_preview_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_planner_form.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_pin_button.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/route_preview_map.dart';

/// The map above `JourneyForm`: one widget for planning and editing, so the
/// two work alike. The text fields stay the journey's own words, and a
/// journey needs nothing else: the map adds where they are.
class JourneyPlanner extends StatefulWidget {
  const JourneyPlanner({
    required this.from,
    required this.to,
    required this.departsAt,
    required this.onDeparture,
    required this.past,
    required this.onPlaces,
    this.keptDeparture,
    this.originPlace,
    this.destinationPlace,
    super.key,
  });

  final TextEditingController from;
  final TextEditingController to;
  final DateTime? departsAt;
  final ValueChanged<DateTime> onDeparture;
  final List<JourneyModel> past;
  final ValueChanged<PlannedPlaces> onPlaces;
  final DateTime? keptDeparture;
  final JourneyPlace? originPlace;
  final JourneyPlace? destinationPlace;

  @override
  State<JourneyPlanner> createState() => _JourneyPlannerState();
}

class _JourneyPlannerState extends State<JourneyPlanner> {
  final MapController _map = MapController();
  final RoutePreviewCubit _preview = sl<RoutePreviewCubit>();
  late JourneyPlace? _origin = widget.originPlace;
  late JourneyPlace? _destination = widget.destinationPlace;
  PlannedRoute? _route;

  TextEditingController get _from => widget.from;
  TextEditingController get _to => widget.to;

  @override
  void initState() {
    super.initState();
    _from.addListener(_typed);
    _to.addListener(_typed);
    _changed();
  }

  @override
  void dispose() {
    _from.removeListener(_typed);
    _to.removeListener(_typed);
    _map.dispose();
    unawaited(_preview.close());
    super.dispose();
  }

  /// Words typed over a pin are a different place: the pin goes.
  void _typed() {
    final bool originGone =
        _origin != null && _from.text.trim() != _origin!.name.trim();
    final bool destinationGone =
        _destination != null && _to.text.trim() != _destination!.name.trim();
    if (!originGone && !destinationGone) return;
    setState(() {
      if (originGone) _origin = null;
      if (destinationGone) _destination = null;
    });
    _changed();
  }

  void _changed() {
    final LatLng? a = _origin?.point;
    final LatLng? b = _destination?.point;
    unawaited(_preview.update(a, b));
    if (a == null || b == null) _route = null;
    _report();
  }

  void _report() => widget.onPlaces((
    origin: _origin,
    destination: _destination,
    route: _route,
  ));

  Future<void> _pick(MapPlaceKind kind) async {
    final bool start = kind == MapPlaceKind.start;
    final JourneyPlace? place = await PlacePinButton.pick(
      context,
      kind,
      start ? _origin : _destination,
    );
    if (place == null || !mounted) return;
    setState(() => start ? _origin = place : _destination = place);
    (start ? _from : _to).text = place.name;
    _changed();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<RoutePreviewCubit>.value(
    value: _preview,
    child: BlocListener<RoutePreviewCubit, RoutePreviewState>(
      listener: (BuildContext context, RoutePreviewState state) {
        _route = state.route;
        _report();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RoutePreviewMap(
            controller: _map,
            origin: _origin,
            destination: _destination,
            onTap: () => _pick(
              _origin == null ? MapPlaceKind.start : MapPlaceKind.destination,
            ),
          ),
          Gap(18.fx),
          JourneyPlannerForm(
            planner: widget,
            originPinned: _origin != null,
            destinationPinned: _destination != null,
            onPick: _pick,
          ),
        ],
      ),
    ),
  );
}
