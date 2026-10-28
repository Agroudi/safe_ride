import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// Ties [child] to how far page [index] of [pages] is from the centre of the
/// view, `d = clamp(page − index, −1, 1)`, with no clock of its own: a finger,
/// a Next tap and the back gesture look identical, and nothing replays.
///
/// - [lag] (raw design units): the child shifts `directionSign × d × lag.fx`
///   against its page, so it travels a little slower than the page — depth
///   without zoom. The illustration's scene only; text never gets parallax.
/// - [fade]: the child's opacity is `1 − |d| / AppMotion.copyFadeSpan`, so the
///   outgoing copy is gone before the incoming copy is readable.
///
/// Paint only. Returns [child] untouched under reduced motion.
class PageParallax extends StatelessWidget {
  const PageParallax({
    required this.pages,
    required this.index,
    required this.child,
    this.lag = 0,
    this.fade = false,
    super.key,
  });

  final PageController pages;

  /// The page [child] belongs to.
  final int index;
  final Widget child;

  /// Raw design units the child lags by one page away (`.fx` is applied
  /// here).
  final double lag;

  /// True: the child fades out as its page leaves.
  final bool fade;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion || (lag <= 0 && !fade)) return child;
    final double shift = context.directionSign * lag.fx;

    return AnimatedBuilder(
      animation: pages,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final bool ready = pages.hasClients && pages.position.haveDimensions;
        // `page` grows going forward in both languages; only the screen
        // direction of "forward" flips, which [shift] carries.
        final double d = ready ? (pages.page! - index).clamp(-1.0, 1.0) : 0;
        Widget moved = child!;
        if (lag > 0) {
          moved = Transform.translate(
            offset: Offset(d * shift, 0),
            child: moved,
          );
        }
        if (fade) {
          final double opacity = 1 - d.abs() / AppMotion.copyFadeSpan;
          moved = Opacity(opacity: opacity.clamp(0.0, 1.0), child: moved);
        }
        return moved;
      },
    );
  }
}
