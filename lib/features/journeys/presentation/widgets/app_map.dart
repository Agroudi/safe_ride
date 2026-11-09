import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_credit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_defaults.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_notice.dart';

/// The one map in the app: tiles in the current theme, the required credit,
/// and whatever [layers] a screen draws over them.
///
/// **The picture is optional.** If tiles fail, [layers] carry on over a plain
/// ground with a note saying so; nothing that uses a map depends on them.
/// A theme change swaps only the tile layer: [controller] keeps the camera
/// and [layers] stay as they are.
class AppMap extends StatefulWidget {
  const AppMap({
    required this.controller,
    this.center = MapDefaults.center,
    this.zoom = MapDefaults.zoom,
    this.fit,
    this.layers = const <Widget>[],
    this.onTap,
    this.onMoved,
    this.onReady,
    this.credit,
    this.showCredit = true,
    this.noticeTop = 0,
    super.key,
  });

  final MapController controller;
  final LatLng center;
  final double zoom;

  /// Overrides [center] and [zoom] when the opening view is an area.
  final CameraFit? fit;
  final List<Widget> layers;
  final ValueChanged<LatLng>? onTap;

  /// The camera moved; true when the user's finger moved it.
  final void Function(MapCamera camera, bool byUser)? onMoved;
  final VoidCallback? onReady;

  /// Another provider's required credit, beside the tiles'.
  final String? credit;

  /// False when a panel would cover the corner: the screen then shows
  /// [MapCredit] above its panel instead. It is never left out.
  final bool showCredit;

  /// Room left at the top before the offline note.
  final double noticeTop;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  final MapTileProvider _tiles = sl<MapTileProvider>();
  Widget? _layer;
  bool? _dark;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dark != context.isDark) {
      _dark = context.isDark;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final bool dark = context.isDark;
    try {
      final Widget layer = await _tiles.layer(
        dark: dark,
        colors: context.appColors,
      );
      if (mounted && dark == _dark) {
        setState(() {
          _layer = layer;
          _failed = false;
        });
      }
    } on MapFailure {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget? layer = _layer;

    // Expand: with no tiles to size it, the map would otherwise be nothing,
    // and offline a pin could not be placed.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            initialCameraFit: widget.fit,
            minZoom: 3,
            maxZoom: 19,
            backgroundColor: context.appColors.background,
            // North stays up: a turned map is one more thing to read.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: widget.onTap == null
                ? null
                : (_, LatLng point) => widget.onTap!(point),
            onPositionChanged: widget.onMoved,
            onMapReady: widget.onReady,
          ),
          children: <Widget>[?layer, ...widget.layers],
        ),
        PositionedDirectional(
          top: widget.noticeTop + 8.fx,
          start: 12.fx,
          end: 12.fx,
          child: MapTilesNotice(
            reachable: _tiles.reachable,
            failed: _failed,
            onRetry: _load,
          ),
        ),
        if (widget.showCredit) MapCornerCredit(extra: widget.credit),
      ],
    );
  }
}
