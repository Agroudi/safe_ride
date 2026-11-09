import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/app_map.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_map_controls.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_map_layers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_defaults.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_glide.dart';

/// The map of a journey and what floats on it. The camera follows the
/// position until the user moves the map, and stays where they put it until
/// they ask to follow again.
class JourneyLiveMap extends StatefulWidget {
  const JourneyLiveMap({required this.opening, super.key});

  /// The state when the map opened: where the camera starts.
  final JourneyMapState opening;

  @override
  State<JourneyLiveMap> createState() => _JourneyLiveMapState();
}

class _JourneyLiveMapState extends State<JourneyLiveMap>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  late final MapGlide _glide;
  late bool _following = widget.opening.status != MapTrackingStatus.completed;

  @override
  void initState() {
    super.initState();
    _glide = MapGlide(vsync: this, map: _map);
  }

  @override
  void dispose() {
    _glide.dispose();
    _map.dispose();
    super.dispose();
  }

  void _follow(LatLng to, {double? zoom}) => _glide.to(
    to,
    zoom: zoom ?? _map.camera.zoom,
    instantly: context.reduceMotion,
  );

  void _moved(MapCamera camera, bool byUser) {
    if (byUser && _following) {
      _glide.stop();
      setState(() => _following = false);
    }
  }

  void _recenter(TrackPoint at) {
    setState(() => _following = true);
    _follow(
      LatLng(at.lat, at.lng),
      zoom: math.max(_map.camera.zoom, MapDefaults.closeZoom),
    );
  }

  void _zoom(double by) {
    _glide.stop();
    _map.move(_map.camera.center, _map.camera.zoom + by);
  }

  /// The whole journey, for one that has ended or has no position yet.
  CameraFit? _overview() {
    final JourneyModel? j = widget.opening.journey;
    final List<LatLng> all = <LatLng>[
      ?j?.originPlace?.point,
      ?j?.destinationPlace?.point,
      for (final List<LatLng> segment
          in context.read<JourneyMapCubit>().segments)
        ...segment,
    ];
    if (all.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: all,
      padding: const EdgeInsets.fromLTRB(48, 110, 48, 220),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TrackPoint? at = widget.opening.current;
    final LatLng? start = at == null ? null : LatLng(at.lat, at.lng);
    final bool close = _following && start != null;

    return BlocListener<JourneyMapCubit, JourneyMapState>(
      listenWhen: (JourneyMapState a, JourneyMapState b) =>
          a.current != b.current,
      listener: (BuildContext context, JourneyMapState state) {
        final TrackPoint? now = state.current;
        if (_following && now != null) _follow(LatLng(now.lat, now.lng));
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: start ?? MapDefaults.center,
              zoom: start == null ? MapDefaults.zoom : MapDefaults.closeZoom,
              fit: close ? null : _overview(),
              onMoved: _moved,
              showCredit: false,
              // Clear of the back button, under any status bar.
              noticeTop: MediaQuery.paddingOf(context).top + 72.fx,
              layers: const <Widget>[JourneyMapLayers()],
            ),
          ),
          PositionedDirectional(
            top: 0,
            start: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.screenSide),
                child: const AppBackButton(),
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: JourneyMapFooter(
              following: _following,
              onZoom: _zoom,
              onRecenter: _recenter,
            ),
          ),
        ],
      ),
    );
  }
}
