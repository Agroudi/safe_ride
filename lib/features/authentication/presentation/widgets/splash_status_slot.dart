import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/authentication/logic/states/startup_state.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_failure.dart';

/// The slot under the splash's brand: empty until the intro is over — so
/// nothing moves the brand during the launch hand-off — then a spinner while
/// startup is still deciding, or the failure and its retry.
///
/// What appears fades in once, never over a hidden live spinner. The slot
/// changes size on `AppCurves.move`, so the centred brand glides instead of
/// jumping. A spinner after a retry, and the failure view leaving on one, are
/// instant: a tap is answered at once. Instant under reduced motion too.
class SplashStatusSlot extends StatelessWidget {
  const SplashStatusSlot({
    required this.state,
    required this.introFinished,
    required this.attempt,
    required this.onRetry,
    super.key,
  });

  final StartupState state;
  final bool introFinished;

  /// Retries so far. Keys each failure view, so a failure after a retry is a
  /// new live region that a screen reader announces again.
  final int attempt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = context.reduceMotion;
    final Duration change = reduceMotion ? Duration.zero : AppDurations.short;
    final Widget empty = SizedBox.square(dimension: 26.fx);

    final Widget content = !introFinished
        ? empty
        : switch (state) {
            StartupLoading() => _FadeIn(
              key: const ValueKey<String>('loading'),
              duration: attempt > 0 ? Duration.zero : change,
              child: SizedBox.square(
                dimension: 26.fx,
                child: CircularProgressIndicator(
                  strokeWidth: 3.fx,
                  strokeCap: StrokeCap.round,
                  semanticsLabel: context.tr('splash.loading'),
                ),
              ),
            ),
            StartupFailed() => _FadeIn(
              key: ValueKey<int>(attempt),
              duration: change,
              child: SplashFailure(
                key: ValueKey<int>(attempt),
                title: context.tr('splash.failedTitle'),
                body: context.tr('splash.failedBody'),
                retryLabel: context.tr('splash.retry'),
                onRetry: onRetry,
              ),
            ),
            StartupReady() => empty,
          };

    // ⚠️ No `AnimatedSize` at all under reduced motion: at `Duration.zero`
    // it re-dirties itself inside its own layout, which asserts.
    if (reduceMotion) return content;
    return AnimatedSize(
      duration: change,
      curve: AppCurves.move,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

/// [child] fading in over [duration] when it first appears, linear and in
/// place, its semantics present throughout.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.duration, required this.child, super.key});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      builder: (BuildContext context, double opacity, Widget? child) =>
          Opacity(opacity: opacity, alwaysIncludeSemantics: true, child: child),
      child: child,
    );
  }
}
