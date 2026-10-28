import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';

/// A control that gives a little under the finger: down to
/// `AppMotion.pressScale` in `AppDurations.press`, back in
/// `AppDurations.short`. No bounce.
///
/// It only listens to raw pointers, outside the gesture arena, so the
/// [child]'s taps and ink ripple — the platform's own feedback — are
/// untouched. Inert while not [enabled] and under reduced motion.
///
/// The tree is the same whether it is live or inert: a button that turns busy
/// on tap keeps its subtree, so its label swap still animates and focus is
/// not lost.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = context.reduceMotion;
    final bool live = widget.enabled && !reduceMotion;
    final bool pressed = live && _down;

    return Listener(
      onPointerDown: live ? (_) => _press(true) : null,
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: pressed ? AppMotion.pressScale : 1,
        duration: reduceMotion
            ? Duration.zero
            : pressed
            ? AppDurations.press
            : AppDurations.short,
        curve: pressed ? AppCurves.move : AppCurves.enter,
        child: widget.child,
      ),
    );
  }
}
