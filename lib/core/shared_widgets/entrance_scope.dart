import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';

/// One screen's staged entrance: a single finite clock that every
/// `EntranceItem` below it reads its own slice of.
///
/// It starts **once**, when the screen first builds; a later MediaQuery,
/// locale or theme change never replays it, and nothing repeats. Items listen
/// through transitions, so nothing rebuilds per frame. A ticker of its own,
/// so `TickerMode` pauses it on a covered route and while backgrounded.
///
/// - [startWhen]: the clock holds at 0 until the future completes (the
///   splash waits for the launch hand-off), then runs.
/// - Reduced motion: the clock is at its end on the first frame. If the flag
///   turns on mid-run, it jumps to its end.
/// - Covered by a push mid-entrance (not replaced by a `go`): it jumps to its
///   end, so going back never finds a half-finished screen.
/// - [onComplete] runs once, after the frame in which the entrance ends —
///   never on dispose, which does not complete it. Post-frame, because under
///   reduced motion it ends inside the first build and the caller may call
///   `setState`.
class EntranceScope extends StatefulWidget {
  const EntranceScope({
    required this.duration,
    required this.child,
    this.onComplete,
    this.startWhen,
    super.key,
  });

  /// The whole entrance; items place themselves on it.
  final Duration duration;
  final Widget child;
  final VoidCallback? onComplete;

  /// When given, the entrance starts when this completes rather than on the
  /// first build. Read once.
  final Future<void>? startWhen;

  /// The entrance's 0..1 clock, or null outside any scope.
  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EntranceData>()?.animation;

  /// The length of the enclosing entrance; zero outside any scope.
  static Duration durationOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EntranceData>()?.duration ??
      Duration.zero;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);

  bool _started = false;
  bool _completed = false;

  /// Holding at 0 for [EntranceScope.startWhen].
  bool _waiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = context.reduceMotion;
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final bool covered = route != null && route.isActive && !route.isCurrent;

    if (!_started) {
      _started = true;
      final Future<void>? gate = widget.startWhen;
      if (reduceMotion) {
        _clock.value = 1;
      } else if (gate == null) {
        _clock.forward();
      } else {
        _waiting = true;
        gate.whenComplete(_release);
      }
    } else if ((_clock.isAnimating || _waiting) && (reduceMotion || covered)) {
      _waiting = false;
      _clock.value = 1;
    }
  }

  void _release() {
    if (!mounted || !_waiting) return;
    _waiting = false;
    _clock.forward();
  }

  @override
  void didUpdateWidget(EntranceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clock.duration = widget.duration;
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    _completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntranceData(
    animation: _clock,
    duration: widget.duration,
    child: widget.child,
  );
}

class _EntranceData extends InheritedWidget {
  const _EntranceData({
    required this.animation,
    required this.duration,
    required super.child,
  });

  final Animation<double> animation;
  final Duration duration;

  @override
  bool updateShouldNotify(_EntranceData oldWidget) =>
      oldWidget.duration != duration;
}
