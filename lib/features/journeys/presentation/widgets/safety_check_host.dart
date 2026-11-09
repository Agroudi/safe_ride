import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/safety/escalation_gate.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_check_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/safety_check_prompt.dart';

/// Lays the safety-check prompt over every route (`MaterialApp.builder`),
/// so "Are you okay?" appears wherever the user is. Picks up a running or
/// overdue check at app start and whenever the app comes back to the
/// foreground; off screen, the service shows it as a notification, and
/// tapping that opens the app to this prompt.
class SafetyCheckHost extends StatefulWidget {
  const SafetyCheckHost({required this.child, this.onHelp, super.key});

  final Widget child;

  /// Opens the help screen. It sits above the router, so the app says how.
  final VoidCallback? onHelp;

  @override
  State<SafetyCheckHost> createState() => _SafetyCheckHostState();
}

class _SafetyCheckHostState extends State<SafetyCheckHost> {
  late final SafetyCheckCubit _cubit = sl<SafetyCheckCubit>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _cubit.recover,
      onHide: _cubit.hidden,
    );
    _cubit.recover();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _safe() async {
    final ConfirmOutcome? outcome = await _cubit.confirm();
    if (outcome == ConfirmOutcome.confirmed && mounted) {
      sl<AppNotifier>().show(
        AppNotification.success(
          title: context.tr('journeys.safetyCheck.thanks'),
        ),
      );
    }
  }

  Future<void> _okay() async {
    final ResolveOutcome? outcome = await _cubit.resolve();
    if (outcome == ResolveOutcome.resolved && mounted) {
      sl<AppNotifier>().show(
        AppNotification.success(
          title: context.tr('journeys.safetyCheck.thanks'),
        ),
      );
    }
  }

  /// The note closes; the escalation stays open, on the journey screen.
  void _help() {
    _cubit.acknowledge();
    widget.onHelp?.call();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<SafetyCheckCubit>.value(
    value: _cubit,
    child: BlocBuilder<SafetyCheckCubit, SafetyCheckState>(
      builder: (BuildContext context, SafetyCheckState state) {
        final SafetyCheck? check = state.check;
        return Stack(
          children: <Widget>[
            // The page behind is out of reach for a screen reader too.
            ExcludeSemantics(excluding: check != null, child: widget.child),
            if (check != null)
              Positioned.fill(
                child: SafetyCheckPrompt(
                  key: ValueKey<String>(check.id),
                  check: check,
                  now: _cubit.now,
                  total: check.deadline.difference(check.startedAt),
                  confirming: state.confirming,
                  onSafe: _safe,
                  onOkay: _okay,
                  onHelp: _help,
                  onClose: _cubit.acknowledge,
                ),
              ),
          ],
        );
      },
    ),
  );
}
