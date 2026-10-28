import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/halo_ring.dart';

export 'package:safe_ride/features/authentication/presentation/widgets/halo_ring.dart'
    show HaloRing;

/// Concentric decorative rings that never stop moving: a slow breath rolls
/// outward through them, each ring a beat after the one inside it, and a
/// dotted orbit turns — clockwise in English, the other way in Arabic.
///
/// With [enter] the rings also open inner to outer on beats 0, 1, 2… of the
/// page's `EntranceScope`. Inner to outer in [rings]; the last is the widest
/// and sets the size.
///
/// One controller and one repaint boundary: a frame repaints only the rings —
/// no layout, no rebuild, no extra layer. `TickerMode` pauses the loop on a
/// covered route and in the background; under reduced motion the rings rest.
/// Decorative: no semantics.
class HaloRings extends StatefulWidget {
  const HaloRings({required this.rings, this.enter = true, super.key});

  final List<HaloRing> rings;
  final bool enter;

  /// Tests turn the loop off in `test/flutter_test_config.dart` — a loop
  /// never settles, so `pumpAndSettle` would time out on every screen that
  /// shows the rings. `halo_rings_test` turns it back on.
  @visibleForTesting
  static bool ambient = true;

  @override
  State<HaloRings> createState() => _HaloRingsState();
}

class _HaloRingsState extends State<HaloRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: AppDurations.haloCycle,
  );

  bool get _still => !HaloRings.ambient || context.reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<HaloRing> rings = widget.rings;
    final bool still = _still;
    final double sign = context.directionSign;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: rings.last.diameter,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (int i = rings.length - 1; i >= 0; i--)
                EntranceItem.beat(
                  i,
                  scaleFrom: AppMotion.ringFrom,
                  enabled: widget.enter,
                  child: CustomPaint(
                    size: Size.square(rings[i].diameter),
                    painter: HaloRingPainter(
                      ring: rings[i],
                      index: i,
                      clock: _clock,
                      still: still,
                      sign: sign,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
