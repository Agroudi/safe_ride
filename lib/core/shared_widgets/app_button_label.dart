import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// A button's label, or its spinner while [busy]: a change swaps them in
/// place — the new one rises in as the old one rises out.
///
/// The outgoing label is excluded from semantics, so a frame in the middle
/// of "Next" → "Get started" announces only "Get started". Both sit in one
/// centred stack, so the button never changes size. Instant under reduced
/// motion.
class AppButtonLabel extends StatelessWidget {
  const AppButtonLabel({
    required this.label,
    required this.busy,
    required this.color,
    required this.style,
    super.key,
  });

  final String label;
  final bool busy;

  /// The label's and the spinner's colour.
  final Color color;
  final TextStyle? style;

  /// Not a label: a label could be any string.
  static const Object _spinner = Object();

  @override
  Widget build(BuildContext context) {
    final Key current = ValueKey<Object>(busy ? _spinner : label);
    final double shift = AppMotion.labelShift.fx;

    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : AppDurations.short,
      // A new closure each build, so the switcher re-runs it for the
      // children already on screen and the old one becomes "outgoing".
      transitionBuilder: (Widget child, Animation<double> animation) =>
          child.key == current
          ? _Swap(animation: animation, shift: shift, child: child)
          : ExcludeSemantics(
              child: _Swap(
                animation: animation,
                shift: -shift,
                outgoing: true,
                child: child,
              ),
            ),
      child: busy
          ? SizedBox.square(
              key: current,
              dimension: 20.fx,
              child: CircularProgressIndicator(strokeWidth: 2.fx, color: color),
            )
          : Text(
              label,
              key: current,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(color: color),
            ),
    );
  }
}

/// Opacity follows [animation] linearly (AnimatedSwitcher runs an outgoing
/// child's backwards, 1 → 0). The incoming child travels from [shift] to 0
/// on `enter`; the [outgoing] one from 0 to [shift] on `exit`.
class _Swap extends StatelessWidget {
  const _Swap({
    required this.animation,
    required this.shift,
    required this.child,
    this.outgoing = false,
  });

  final Animation<double> animation;
  final double shift;
  final bool outgoing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 1 → 0 as the label travels away from its resting place.
    final Animation<double> away = outgoing
        ? ReverseAnimation(animation).drive(CurveTween(curve: AppCurves.exit))
        : ReverseAnimation(animation.drive(CurveTween(curve: AppCurves.enter)));

    return FadeTransition(
      opacity: animation,
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: away,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, shift * away.value),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
