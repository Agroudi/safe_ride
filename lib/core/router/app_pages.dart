import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// The page every route builds. Two recipes, **one page type**:
///
/// - [stage] — for `go` targets (splash, onboarding, welcome, home): a
///   fade-through. No scale, no slide, so it is right whether the user went
///   forward or "up".
/// - [task] — for pushes (login, register, recovery): the same fades plus a
///   short travel in from the reading direction's **end** side (right in
///   English, left in Arabic); a pop runs it in reverse.
///
/// ⚠️ Every `GoRoute` uses `pageBuilder:` with one of these, never
/// `builder:`, and there is no theme-level `PageTransitionsBuilder`. A
/// `MaterialPage` over a `CustomTransitionPage` proxies the covered page's
/// secondary animation to dismissed, so its exit silently never plays.
///
/// The covered page only fades (a push and a `go` look alike from its
/// secondary animation). Under reduced motion both recipes take zero time,
/// read in `pageBuilder`, and draw the page as is.
abstract final class AppPages {
  /// `extra` marking the back dispatcher's `go` "up": a [task] route reached
  /// with it arrives with the [stage] fade, so back never looks like forward.
  /// A String, so go_router's JSON encoding of `extra` never warns.
  static const String up = 'app.navigation.up';

  static Page<void> stage(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => _page(context, state, child, _stage);

  static Page<void> task(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) => _page(context, state, child, state.extra == up ? _stage : _task);

  /// Named, argued and restored as go_router's own `MaterialPage` is.
  static Page<void> _page(
    BuildContext context,
    GoRouterState state,
    Widget child,
    RouteTransitionsBuilder transitions,
  ) {
    final String? name = state.name ?? state.path;
    final Map<String, String> arguments = <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    };

    // iOS: one page type there too, so the edge swipe-back keeps working.
    // ⚠️ Not yet verified on an iOS device or simulator.
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoPage<void>(
        key: state.pageKey,
        name: name,
        arguments: arguments,
        restorationId: state.pageKey.value,
        child: child,
      );
    }

    final Duration duration = context.reduceMotion
        ? Duration.zero
        : AppDurations.medium;
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: name,
      arguments: arguments,
      restorationId: state.pageKey.value,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: transitions,
      child: child,
    );
  }

  /// Out by 140 ms of 400; in from 120 ms, linear.
  static final Animatable<double> _fadeOut = CurveTween(
    curve: const Interval(0, AppMotion.fadeOutEnd, curve: AppCurves.exit),
  );
  static final Animatable<double> _fadeIn = CurveTween(
    curve: const Interval(AppMotion.fadeInStart, 1),
  );

  static final Animatable<double> _travel = CurveTween(curve: AppCurves.enter);

  static Widget _stage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    if (context.reduceMotion) return child;
    return FadeTransition(
      opacity: ReverseAnimation(secondary.drive(_fadeOut)),
      child: FadeTransition(opacity: animation.drive(_fadeIn), child: child),
    );
  }

  static Widget _task(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    if (context.reduceMotion) return child;
    return FadeTransition(
      opacity: ReverseAnimation(secondary.drive(_fadeOut)),
      child: FadeTransition(
        opacity: animation.drive(_fadeIn),
        child: _AxisShift(
          progress: animation.drive(_travel),
          distance: AppMotion.axis.fx * context.directionSign,
          child: child,
        ),
      ),
    );
  }
}

/// [child] painted [distance] along x at 0 and in place at 1 — paint only,
/// never a relayout; hit tests follow the paint.
class _AxisShift extends AnimatedWidget {
  const _AxisShift({
    required Animation<double> progress,
    required this.distance,
    required this.child,
  }) : super(listenable: progress);

  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double progress = (listenable as Animation<double>).value;
    return Transform.translate(
      offset: Offset(distance * (1 - progress), 0),
      child: child,
    );
  }
}
