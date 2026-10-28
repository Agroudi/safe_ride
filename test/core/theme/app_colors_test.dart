import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The roles that carry a promise beyond their value: small teal text that
/// reads (WCAG AA, 4.5:1), and roles that animate with the theme instead of
/// silently keeping the old palette's value.
void main() {
  for (final (String name, AppColors colors) in <(String, AppColors)>[
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    test('accentText reads as small text on background in $name', () {
      expect(
        _contrast(colors.accentText, colors.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accentText reads as small text on surface in $name', () {
      expect(
        _contrast(colors.accentText, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('the mark reads on the launch tile in $name', () {
      expect(
        _contrast(colors.onLaunchTile, colors.launchTile),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  // Why the role exists: the fill teal is too light for small text on the
  // light background. If this ever passes, accentText can go.
  test('secondary is below 4.5:1 as small text in light', () {
    expect(
      _contrast(AppColors.light.secondary, AppColors.light.background),
      lessThan(4.5),
    );
  });

  // A role missing from copyWith or lerp stays the old value when the theme
  // changes — the analyzer does not notice.
  group('new roles go through copyWith and lerp', () {
    const Color probe = Color(0xFF123456);

    test('accentText', () {
      expect(AppColors.light.copyWith(accentText: probe).accentText, probe);
      expect(
        AppColors.light.lerp(AppColors.dark, 1).accentText,
        AppColors.dark.accentText,
      );
      expect(
        AppColors.light.lerp(AppColors.dark, 0.5).accentText,
        Color.lerp(AppColors.light.accentText, AppColors.dark.accentText, 0.5),
      );
    });

    test('launchTile', () {
      expect(AppColors.light.copyWith(launchTile: probe).launchTile, probe);
      expect(
        AppColors.light
            .lerp(AppColors.dark.copyWith(launchTile: probe), 1)
            .launchTile,
        probe,
      );
    });

    test('onLaunchTile', () {
      expect(AppColors.light.copyWith(onLaunchTile: probe).onLaunchTile, probe);
      expect(
        AppColors.light
            .lerp(AppColors.dark.copyWith(onLaunchTile: probe), 1)
            .onLaunchTile,
        probe,
      );
    });
  });
}

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
