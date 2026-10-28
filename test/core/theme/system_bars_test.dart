import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/theme/system_bars.dart';

/// The style `main` sets before the first frame: light icons over a dark
/// app, dark icons over a light one, and `system` read from the device.
void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);

  test('a chosen theme sets the icons whatever the device says', () {
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;

    expect(
      SystemBars.styleForMode(ThemeMode.dark).statusBarIconBrightness,
      Brightness.light,
    );
    expect(
      SystemBars.styleForMode(ThemeMode.light).statusBarIconBrightness,
      Brightness.dark,
    );
  });

  for (final Brightness device in Brightness.values) {
    test('system follows a ${device.name} device', () {
      binding.platformDispatcher.platformBrightnessTestValue = device;

      final SystemUiOverlayStyle style = SystemBars.styleForMode(
        ThemeMode.system,
      );

      expect(style, SystemBars.styleFor(device));
      expect(
        style.statusBarIconBrightness,
        device == Brightness.dark ? Brightness.light : Brightness.dark,
      );
    });
  }
}
