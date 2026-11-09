import 'package:latlong2/latlong.dart';

/// Where a map with nothing to show opens: the supported countries.
abstract final class MapDefaults {
  static const LatLng center = LatLng(26, 42);
  static const double zoom = 4;
  static const double closeZoom = 16;
}
