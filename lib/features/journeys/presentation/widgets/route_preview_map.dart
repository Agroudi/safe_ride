import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/logic/cubit/route_preview_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/app_map.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_defaults.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/route_summary_line.dart';

/// The planning map: both places, the route between them, and what the
/// provider estimates, or why it cannot. Tapping it opens the place picker.
class RoutePreviewMap extends StatelessWidget {
  const RoutePreviewMap({
    required this.controller,
    required this.origin,
    required this.destination,
    required this.onTap,
    super.key,
  });

  final MapController controller;
  final JourneyPlace? origin;
  final JourneyPlace? destination;
  final VoidCallback onTap;

  void _frame(RoutePreviewState state) {
    final List<LatLng> points = <LatLng>[
      ...?state.route?.points,
      ?origin?.point,
      ?destination?.point,
    ];
    if (points.length < 2) {
      if (points.isNotEmpty) {
        controller.move(points.single, MapDefaults.closeZoom);
      }
      return;
    }
    controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        // More above: a pin stands up from its point.
        padding: const EdgeInsets.fromLTRB(44, 64, 44, 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JourneyPlace? a = origin;
    final JourneyPlace? b = destination;

    return BlocConsumer<RoutePreviewCubit, RoutePreviewState>(
      listener: (_, RoutePreviewState state) => _frame(state),
      builder: (BuildContext context, RoutePreviewState state) {
        final List<LatLng>? line = state.route?.points;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(18.fx),
              child: SizedBox(
                height: 210.fx,
                child: AppMap(
                  controller: controller,
                  center: a?.point ?? b?.point ?? MapDefaults.center,
                  zoom: a == null && b == null
                      ? MapDefaults.zoom
                      : MapDefaults.closeZoom,
                  onTap: (_) => onTap(),
                  onReady: () => _frame(state),
                  credit: line == null ? null : 'OSRM',
                  layers: <Widget>[
                    if (line != null)
                      PolylineLayer(
                        polylines: <Polyline>[
                          Polyline(
                            points: line,
                            strokeWidth: 5,
                            color: context.appColors.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: <Marker>[
                        if (a != null)
                          placeMarker(
                            a.point,
                            MapPlaceKind.start,
                            context.tr('journeys.map.start'),
                          ),
                        if (b != null)
                          placeMarker(
                            b.point,
                            MapPlaceKind.destination,
                            context.tr('journeys.map.destination'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            RouteSummaryLine(state: state),
          ],
        );
      },
    );
  }
}
