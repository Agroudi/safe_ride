import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';

/// Where the map providers are. Build-time, so a self-hosted or paid
/// replacement needs no code: `--dart-define=MAP_ROUTING_URL=…`. None of
/// these needs a key (docs/maps.md).
abstract final class MapProviders {
  static const String tiles = String.fromEnvironment(
    'MAP_TILES_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles',
  );
  static const String geocoding = String.fromEnvironment(
    'MAP_GEOCODING_URL',
    defaultValue: 'https://photon.komoot.io',
  );
  static const String routing = String.fromEnvironment(
    'MAP_ROUTING_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  /// Every provider's policy asks for an app to name itself.
  static const Map<String, String> headers = <String, String>{
    'User-Agent': 'SafeRide/1.0 (com.saferide.falcon)',
  };
}

/// One JSON GET to a map provider: the app's name, a time limit, and every
/// failure turned into a [MapFailure]. Requests carry only what the caller
/// put in the URL and are never logged.
class MapHttp {
  const MapHttp(this._client);

  final http.Client _client;

  static const Duration _wait = Duration(seconds: 10);

  /// [cancel] completing aborts the request.
  Future<Map<String, dynamic>> getJson(Uri uri, {Future<void>? cancel}) async {
    try {
      final http.AbortableRequest request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: cancel,
      )..headers.addAll(MapProviders.headers);
      final http.Response response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(_wait);
      // Some answers carry their own meaning in a 4xx body (OSRM's NoRoute).
      if (response.statusCode >= 500 || response.statusCode == 429) {
        throw const MapFailure(MapFailureCode.unavailable);
      }
      final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) return body;
      throw const MapFailure(MapFailureCode.unavailable);
    } on MapFailure {
      rethrow;
    } on http.RequestAbortedException {
      throw const MapFailure(MapFailureCode.cancelled);
    } on TimeoutException {
      throw const MapFailure(MapFailureCode.offline);
    } on SocketException {
      throw const MapFailure(MapFailureCode.offline);
    } on http.ClientException {
      throw const MapFailure(MapFailureCode.offline);
    } on FormatException {
      throw const MapFailure(MapFailureCode.unavailable);
    }
  }
}
