import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';

/// Short straight camera moves, so a map following a position glides to it
/// instead of jumping.
class MapGlide {
  MapGlide({required TickerProvider vsync, required MapController map})
    : _map = map,
      _run = AnimationController(vsync: vsync, duration: AppDurations.short) {
    _run.addListener(_step);
  }

  final MapController _map;
  final AnimationController _run;
  LatLng? _from;
  LatLng? _to;
  double _zoom = 0;

  void to(LatLng point, {required double zoom, required bool instantly}) {
    if (instantly) {
      _map.move(point, zoom);
      return;
    }
    _from = _map.camera.center;
    _to = point;
    _zoom = zoom;
    _run.forward(from: 0);
  }

  void stop() => _run.stop();

  void dispose() => _run.dispose();

  void _step() {
    final LatLng? from = _from;
    final LatLng? to = _to;
    if (from == null || to == null) return;
    final double t = AppCurves.move.transform(_run.value);
    _map.move(
      LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
      _zoom,
    );
  }
}
