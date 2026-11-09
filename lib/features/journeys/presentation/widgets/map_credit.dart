import 'package:flutter/material.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/repository/map_tile_provider.dart';

/// The providers' credit. Never hidden: their terms require it on the map.
class MapCredit extends StatelessWidget {
  const MapCredit({this.extra, super.key});

  /// Another provider's credit, beside the tiles'.
  final String? extra;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.appColors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(6.fx),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.fx, vertical: 2.fx),
      child: Text(
        <String>[sl<MapTileProvider>().attribution, ?extra].join(' · '),
        textDirection: TextDirection.ltr,
        style: context.texts.labelSmall?.copyWith(
          color: context.appColors.textMuted,
          fontSize: 9.fsp,
        ),
      ),
    ),
  );
}

/// [MapCredit] in the map's corner, for a `Stack` over the map.
class MapCornerCredit extends StatelessWidget {
  const MapCornerCredit({this.extra, super.key});

  final String? extra;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
    bottom: 4.fx,
    start: 6.fx,
    end: 6.fx,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: MapCredit(extra: extra),
    ),
  );
}
