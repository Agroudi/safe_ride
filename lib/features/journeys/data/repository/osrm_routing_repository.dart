import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/map_http.dart';
import 'package:safe_ride/features/journeys/data/repository/routing_repository.dart';

/// [RoutingRepository] over OSRM's HTTP API. The default server is the
/// project's demo: "reasonable, non-commercial" use, about one request a
/// second, no guarantee (docs/maps.md). So a route is asked for only when a
/// place changes, never per fix, and the same pair is asked for once.
class OsrmRoutingRepository implements RoutingRepository {
  OsrmRoutingRepository(this._http, {String? baseUrl})
    : _base = baseUrl ?? MapProviders.routing;

  final MapHttp _http;
  final String _base;
  final Map<String, PlannedRoute> _seen = <String, PlannedRoute>{};

  static const int _keep = 10;

  @override
  Future<PlannedRoute> route(LatLng from, LatLng to) async {
    final String pair =
        '${from.longitude.toStringAsFixed(5)},${from.latitude.toStringAsFixed(5)};'
        '${to.longitude.toStringAsFixed(5)},${to.latitude.toStringAsFixed(5)}';
    final PlannedRoute? known = _seen[pair];
    if (known != null) return known;
    final Map<String, dynamic> body = await _http.getJson(
      Uri.parse('$_base/route/v1/driving/$pair').replace(
        queryParameters: const <String, String>{
          'overview': 'full',
          'geometries': 'polyline',
        },
      ),
    );
    final PlannedRoute route = _read(body);
    if (_seen.length >= _keep) _seen.remove(_seen.keys.first);
    _seen[pair] = route;
    return route;
  }

  static PlannedRoute _read(Map<String, dynamic> body) {
    final Object? code = body['code'];
    if (code == 'NoRoute' || code == 'NoSegment') {
      throw const MapFailure(MapFailureCode.noRoute);
    }
    final Object? routes = body['routes'];
    if (code != 'Ok' || routes is! List || routes.isEmpty) {
      throw const MapFailure(MapFailureCode.unavailable);
    }
    final Object? first = routes.first;
    if (first is! Map) throw const MapFailure(MapFailureCode.unavailable);
    final Object? geometry = first['geometry'];
    final Object? distance = first['distance'];
    final Object? duration = first['duration'];
    if (geometry is! String || distance is! num) {
      throw const MapFailure(MapFailureCode.unavailable);
    }
    return PlannedRoute(
      points: decodePolyline(geometry),
      distanceMeters: distance.toDouble(),
      durationSeconds: duration is num ? duration.toDouble() : null,
    );
  }

  /// Google's encoded polyline, five decimals: OSRM's default.
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    int next() {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      return result.isOdd ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      lat += next();
      lng += next();
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
