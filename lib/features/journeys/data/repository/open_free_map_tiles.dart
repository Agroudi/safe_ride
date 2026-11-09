import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/map_http.dart';
import 'package:safe_ride/features/journeys/data/repository/map_style_tuner.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as renderer;

/// [MapTileProvider] over OpenFreeMap: OpenStreetMap data as vector tiles,
/// free with no key or limit, commercial use allowed, no guarantee
/// (docs/maps.md). Vector because a real dark map needs a dark *style*:
/// roads and labels drawn for a dark ground, not a filter over a light one.
///
/// A style is read once per look and kept, so a theme change swaps two
/// finished layers. A failed read is not kept: the next map tries again.
class OpenFreeMapTiles implements MapTileProvider {
  OpenFreeMapTiles(this._client, {String? baseUrl})
    : _base = baseUrl ?? MapProviders.tiles;

  final http.Client _client;
  final String _base;
  final Map<bool, Future<Widget>> _layers = <bool, Future<Widget>>{};
  final ValueNotifier<bool> _reachable = ValueNotifier<bool>(true);

  @override
  String get attribution => '© OpenFreeMap © OpenMapTiles © OpenStreetMap';

  @override
  ValueListenable<bool> get reachable => _reachable;

  @override
  Future<Widget> layer({required bool dark, required AppColors colors}) {
    final Future<Widget> loading = _layers[dark] ??= _load(dark, colors);
    return loading.catchError((Object e) {
      _layers.remove(dark);
      _reachable.value = false;
      throw const MapFailure(MapFailureCode.offline);
    });
  }

  Future<Widget> _load(bool dark, AppColors colors) async {
    final String uri = '$_base/${dark ? 'dark' : 'positron'}';
    final Style style = await StyleReader(
      uri: uri,
      httpHeaders: MapProviders.headers,
    ).read();
    final Map<String, dynamic> json = await _json(uri);
    final renderer.Theme theme = renderer.ThemeReader().read(
      dark ? MapStyleTuner.dark(json, colors) : MapStyleTuner.light(json),
    );
    _reachable.value = true;
    return VectorTileLayer(
      key: ValueKey<bool>(dark),
      theme: theme,
      sprites: style.sprites,
      layerMode: VectorTileLayerMode.raster,
      tileProviders: TileProviders(<String, VectorTileProvider>{
        for (final MapEntry<String, VectorTileProvider> e
            in style.providers.tileProviderBySource.entries)
          e.key: _Watched(e.value, _reachable),
      }),
    );
  }

  Future<Map<String, dynamic>> _json(String uri) async {
    final http.Response response = await _client.get(
      Uri.parse(uri),
      headers: MapProviders.headers,
    );
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}

/// Reports whether tiles are arriving; the package itself says nothing.
class _Watched extends VectorTileProvider {
  _Watched(this._inner, this._reachable);

  final VectorTileProvider _inner;
  final ValueNotifier<bool> _reachable;

  @override
  int get maximumZoom => _inner.maximumZoom;

  @override
  int get minimumZoom => _inner.minimumZoom;

  @override
  TileOffset get tileOffset => _inner.tileOffset;

  @override
  TileProviderType get type => _inner.type;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      final Uint8List bytes = await _inner.provide(tile);
      _reachable.value = true;
      return bytes;
    } on Object {
      _reachable.value = false;
      rethrow;
    }
  }
}
