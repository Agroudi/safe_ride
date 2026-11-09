import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// Where the map's picture comes from. `OpenFreeMapTiles` implements it;
/// another provider would be one more, chosen in the service locator.
/// Nothing else in the app knows which one is in use.
abstract interface class MapTileProvider {
  /// The credit the provider requires, shown on every map.
  String get attribution;

  /// The tile layer for a map, in the app's light or dark look. Throws
  /// `MapFailure` when the style cannot be reached.
  Future<Widget> layer({required bool dark, required AppColors colors});

  /// False once a tile failed to load, true again when one arrives: the map
  /// says it is offline, and everything drawn over it carries on.
  ValueListenable<bool> get reachable;
}
