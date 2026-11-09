import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';

/// Everything drawn over the tiles on a journey's map. Rebuilds only when
/// the route or the position changes, never for the speed or a status.
class JourneyMapLayers extends StatelessWidget {
  const JourneyMapLayers({super.key});

  static bool _moved(JourneyMapState a, JourneyMapState b) =>
      a.routeVersion != b.routeVersion ||
      a.current != b.current ||
      a.heading != b.heading ||
      a.planned != b.planned ||
      a.journey != b.journey;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return BlocBuilder<JourneyMapCubit, JourneyMapState>(
      buildWhen: _moved,
      builder: (BuildContext context, JourneyMapState state) {
        final JourneyMapCubit cubit = context.read<JourneyMapCubit>();
        final JourneyModel? journey = state.journey;
        final TrackPoint? at = state.current;
        final List<LatLng>? planned = state.planned?.points;
        final LatLng? here = at == null ? null : LatLng(at.lat, at.lng);

        return Stack(
          children: <Widget>[
            if (planned != null)
              PolylineLayer(
                polylines: <Polyline>[
                  Polyline(
                    points: planned,
                    strokeWidth: 5,
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ],
              ),
            // One line per segment: a gap in tracking stays a gap.
            PolylineLayer(
              polylines: <Polyline>[
                for (final List<LatLng> segment in cubit.segments)
                  if (segment.length > 1)
                    Polyline(
                      points: segment,
                      strokeWidth: 6,
                      color: colors.secondary,
                      borderStrokeWidth: 1.5,
                      borderColor: colors.surface,
                    ),
              ],
            ),
            if (here != null)
              CircleLayer(
                circles: <CircleMarker>[
                  CircleMarker(
                    point: here,
                    radius: at!.accuracy,
                    useRadiusInMeter: true,
                    color: colors.info.withValues(alpha: 0.15),
                    borderColor: colors.info.withValues(alpha: 0.4),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: <Marker>[
                if (journey?.originPlace case final place?)
                  placeMarker(
                    place.point,
                    MapPlaceKind.start,
                    context.tr('journeys.map.start'),
                  ),
                if (journey?.destinationPlace case final place?)
                  placeMarker(
                    place.point,
                    MapPlaceKind.destination,
                    context.tr('journeys.map.destination'),
                  ),
                if (here != null)
                  Marker(
                    point: here,
                    width: 30,
                    height: 30,
                    child: CurrentLocationDot(
                      label: context.tr('journeys.map.you'),
                      heading: state.heading,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
