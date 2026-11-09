import 'package:latlong2/latlong.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/repository/geocoding_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/map_http.dart';

/// [GeocodingRepository] over Photon (komoot's public instance by default).
///
/// Photon rather than Nominatim because Nominatim's policy forbids
/// search-as-you-type outright, and Photon is built for it. Its public
/// instance is fair-use with no guarantee, so this stays gentle: the caller
/// debounces, and an answer already seen is never asked for again.
///
/// Photon has no Arabic `lang`; left out, names come in their local language,
/// which is Arabic across the supported countries.
class PhotonGeocodingRepository implements GeocodingRepository {
  PhotonGeocodingRepository(this._http, {String? baseUrl})
    : _base = baseUrl ?? MapProviders.geocoding;

  final MapHttp _http;
  final String _base;
  final Map<String, List<JourneyPlace>> _seen = <String, List<JourneyPlace>>{};

  static const int _limit = 6;
  static const int _keep = 40;

  static Map<String, String> _language(String code) => code == 'ar'
      ? const <String, String>{}
      : const <String, String>{'lang': 'en'};

  @override
  Future<List<JourneyPlace>> search(
    String query, {
    required String languageCode,
    LatLng? near,
    Future<void>? cancel,
  }) async {
    final String q = query.trim();
    final String key = '$languageCode|${q.toLowerCase()}';
    final List<JourneyPlace>? known = _seen[key];
    if (known != null) return known;
    final Map<String, dynamic> body = await _http.getJson(
      Uri.parse('$_base/api').replace(
        queryParameters: <String, String>{
          'q': q,
          'limit': '$_limit',
          ..._language(languageCode),
          // Rounded to about a kilometre: enough to lean the results, and no
          // reason to tell a third party more than that.
          if (near != null) ...<String, String>{
            'lat': near.latitude.toStringAsFixed(2),
            'lon': near.longitude.toStringAsFixed(2),
          },
        },
      ),
      cancel: cancel,
    );
    final List<JourneyPlace> places = _places(body);
    if (_seen.length >= _keep) _seen.remove(_seen.keys.first);
    _seen[key] = places;
    return places;
  }

  @override
  Future<JourneyPlace?> reverse(
    LatLng point, {
    required String languageCode,
  }) async {
    final Map<String, dynamic> body = await _http.getJson(
      Uri.parse('$_base/reverse').replace(
        queryParameters: <String, String>{
          'lat': point.latitude.toStringAsFixed(5),
          'lon': point.longitude.toStringAsFixed(5),
          'limit': '1',
          ..._language(languageCode),
        },
      ),
    );
    final List<JourneyPlace> places = _places(body);
    return places.isEmpty ? null : places.first;
  }

  static List<JourneyPlace> _places(Map<String, dynamic> body) {
    final Object? features = body['features'];
    if (features is! List) return const <JourneyPlace>[];
    // A city is often both a node and a boundary: one line, not two.
    final Set<String> seen = <String>{};
    return <JourneyPlace>[
      for (final Object? f in features)
        if (f is Map<String, dynamic>)
          if (_place(f) case final JourneyPlace p
              when seen.add('${p.name}|${p.address}'))
            p,
    ];
  }

  static JourneyPlace? _place(Map<String, dynamic> feature) {
    final Object? geometry = feature['geometry'];
    final Object? properties = feature['properties'];
    if (geometry is! Map || properties is! Map) return null;
    final Object? at = geometry['coordinates'];
    if (at is! List || at.length < 2 || at[0] is! num || at[1] is! num) {
      return null;
    }
    final double lng = (at[0] as num).toDouble();
    final double lat = (at[1] as num).toDouble();
    if (!JourneyPlace.validCoordinates(lat, lng)) return null;
    String? text(String key) {
      final Object? v = properties[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final String? name = text('name') ?? text('street') ?? text('city');
    if (name == null) return null;
    final List<String> parts = <String>[];
    for (final String key in <String>[
      'street',
      'district',
      'city',
      'state',
      'country',
    ]) {
      final String? part = text(key);
      if (part != null && part != name && !parts.contains(part)) {
        parts.add(part);
      }
    }
    final String? type = text('osm_type');
    final Object? id = properties['osm_id'];
    return JourneyPlace(
      name: name,
      lat: lat,
      lng: lng,
      address: parts.isEmpty ? null : parts.join('، '),
      placeId: type == null || id == null ? null : '$type$id',
    );
  }
}
