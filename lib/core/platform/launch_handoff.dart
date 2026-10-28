import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// When the launch screen has handed the window over to Flutter — the moment
/// the splash intro may start moving.
///
/// On Android 12+ the system splash stays up until Flutter's first frame is
/// on screen, and Flutter's first frame can take hundreds of milliseconds to
/// raster on a cold start. Without this the intro would play behind the
/// system splash and the user would see its end through a fading double
/// image. `MainActivity` removes the system splash the moment it may (frame 0
/// repeats it pixel for pixel) and answers [wait] then.
///
/// Everywhere else — iOS, Android below 12, tests — there is nothing to wait
/// for, and [wait] completes synchronously. It never throws and never waits
/// past [timeout], so a launch without a system splash still starts.
abstract final class LaunchHandoff {
  static const MethodChannel _channel = MethodChannel('safe_ride/launch');

  /// The longest the intro holds frame 0 for an answer.
  static const Duration timeout = Duration(milliseconds: 1200);

  /// Tests turn this off in `test/flutter_test_config.dart`, so a screen's
  /// timing does not depend on a platform channel; the hand-off's own test
  /// turns it back on.
  @visibleForTesting
  static bool enabled = true;

  static Future<void> wait() {
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return SynchronousFuture<void>(null);
    }
    return _channel
        .invokeMethod<void>('handedOff')
        .timeout(timeout)
        .catchError((Object _) {});
  }
}
