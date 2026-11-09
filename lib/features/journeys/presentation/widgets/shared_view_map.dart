import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/logic/cubit/shared_view_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/pages/shared_view_page.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/app_map.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_credit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_defaults.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/shared_view_panel.dart';

/// The map a recipient sees. It follows the position until they move it.
class SharedViewMap extends StatefulWidget {
  const SharedViewMap({super.key});

  @override
  State<SharedViewMap> createState() => _SharedViewMapState();
}

class _SharedViewMapState extends State<SharedViewMap> {
  final MapController _map = MapController();
  bool _following = true;
  LatLng? _centredOn;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _follow(SharedViewState state) {
    final LatLng? at = state.view?.point;
    if (at == null || !_following || at == _centredOn) return;
    _map.move(
      at,
      _centredOn == null ? MapDefaults.closeZoom : _map.camera.zoom,
    );
    _centredOn = at;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SharedViewCubit, SharedViewState>(
      listener: (_, SharedViewState state) => _follow(state),
      builder: (BuildContext context, SharedViewState state) {
        final SharedView? view = state.view;
        final LatLng? at = view?.point;
        final LatLng? from = view?.origin?.point;
        final LatLng? to = view?.destination?.point;
        // An old position is drawn muted: never as if it were live.
        final bool live = state.liveness == SharedLiveness.live;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: AppMap(
                controller: _map,
                center: at ?? from ?? to ?? MapDefaults.center,
                zoom: at == null && from == null && to == null
                    ? MapDefaults.zoom
                    : MapDefaults.closeZoom,
                showCredit: false,
                noticeTop: MediaQuery.paddingOf(context).top + 72,
                onMoved: (MapCamera _, bool byUser) {
                  if (byUser) _following = false;
                },
                layers: <Widget>[
                  PolylineLayer(
                    polylines: <Polyline>[
                      for (final List<LatLng> line
                          in context.read<SharedViewCubit>().segments)
                        Polyline(
                          points: line,
                          strokeWidth: 5,
                          color: context.appColors.secondary,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      if (from != null)
                        placeMarker(
                          from,
                          MapPlaceKind.start,
                          context.tr('journeys.map.start'),
                        ),
                      if (to != null)
                        placeMarker(
                          to,
                          MapPlaceKind.destination,
                          context.tr('journeys.map.destination'),
                        ),
                      if (at != null)
                        Marker(
                          point: at,
                          width: 30,
                          height: 30,
                          child: Opacity(
                            opacity: live ? 1 : 0.55,
                            child: CurrentLocationDot(
                              label: context.tr('sharing.view.position'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.screenSide),
                  child: AppBackButton(
                    onPressed: () => SharedViewPage.leave(context),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 6, bottom: 4),
                    child: MapCredit(),
                  ),
                  SharedViewPanel(state: state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
