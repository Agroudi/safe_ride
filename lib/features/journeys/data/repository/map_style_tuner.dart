import 'dart:ui';

import 'package:safe_ride/core/theme/app_colors.dart';

/// Redraws a dark map style in SafeRide's own colours. OpenFreeMap's dark
/// style sets its labels too dim to read comfortably and its roads darker
/// than the land; here labels get real contrast and roads stand out, from
/// the palette, so the map belongs to the app. Paints are replaced in the
/// style itself, so everything stays crisp: no filter over a finished image.
///
/// ⚠️ Every style gets its own id. The provider's styles have none, so both
/// would read as `default`, and the tile layer keys its caches by id: light
/// mode then drew the dark map's tiles. [version] moves when the tuning does,
/// so cached tiles never outlive a change of colours.
abstract final class MapStyleTuner {
  static const String version = '1';

  static Map<String, dynamic> _named(Map<String, dynamic> style, String id) =>
      <String, dynamic>{
        ...style,
        'id': id,
        'metadata': <String, dynamic>{'version': version},
      };

  static Map<String, dynamic> light(Map<String, dynamic> style) =>
      _named(style, 'saferide-light');

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Map<String, dynamic> dark(
    Map<String, dynamic> style,
    AppColors colors,
  ) {
    final String ground = _hex(colors.background);
    final String water = _hex(
      Color.lerp(colors.background, colors.primaryContainer, 0.7)!,
    );
    final String land = _hex(
      Color.lerp(colors.background, colors.surface, 0.6)!,
    );
    final String road = _hex(
      Color.lerp(colors.border, colors.textMuted, 0.15)!,
    );
    final String majorRoad = _hex(
      Color.lerp(colors.border, colors.textMuted, 0.45)!,
    );
    final String label = _hex(colors.textMuted);

    final List<Object?> layers = <Object?>[];
    for (final Object? entry in style['layers'] as List<Object?>) {
      if (entry is! Map<String, dynamic>) continue;
      final Map<String, dynamic> layer = Map<String, dynamic>.of(entry);
      final Map<String, dynamic> paint = Map<String, dynamic>.of(
        (layer['paint'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
      final String source = (layer['source-layer'] as String?) ?? '';
      final String id = (layer['id'] as String?) ?? '';
      switch (layer['type']) {
        case 'background':
          paint['background-color'] = ground;
        case 'fill':
          paint['fill-color'] = source == 'water' ? water : land;
          paint.remove('fill-outline-color');
        case 'line':
          paint['line-color'] = switch (source) {
            'transportation' =>
              id.contains('motorway') || id.contains('trunk')
                  ? majorRoad
                  : road,
            'waterway' => water,
            _ => _hex(colors.border),
          };
        case 'symbol':
          paint['text-color'] = label;
          paint['text-halo-color'] = ground;
          paint['text-halo-width'] = 1.2;
      }
      layer['paint'] = paint;
      layers.add(layer);
    }
    return _named(<String, dynamic>{
      ...style,
      'layers': layers,
    }, 'saferide-dark');
  }
}
