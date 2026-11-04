import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/safety_check.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/escalation_status.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/safety_check_answer.dart';

/// "Are you okay?" over everything: the question, the seconds left and one
/// large "I'm safe" — nothing to navigate. The seconds are always
/// `deadline − now` ([now]); the refresh only redraws them. Once the check
/// timed out it says so plainly — no answer, what became of the alert as far
/// as is known — and Close.
class SafetyCheckPrompt extends StatefulWidget {
  const SafetyCheckPrompt({
    required this.check,
    required this.now,
    required this.total,
    required this.confirming,
    required this.onSafe,
    required this.onClose,
    super.key,
  });

  final SafetyCheck check;
  final DateTime Function() now;

  /// The whole countdown (15 s).
  final Duration total;
  final bool confirming;
  final VoidCallback onSafe;
  final VoidCallback onClose;

  /// How often the seconds are redrawn.
  static const Duration refresh = Duration(milliseconds: 250);

  @override
  State<SafetyCheckPrompt> createState() => _SafetyCheckPromptState();
}

class _SafetyCheckPromptState extends State<SafetyCheckPrompt> {
  late final Timer _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(SafetyCheckPrompt.refresh, (_) {
      if (widget.check.status == SafetyCheckStatus.pending) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool asking = widget.check.status == SafetyCheckStatus.pending;
    final String key = asking
        ? 'journeys.safetyCheck'
        : 'journeys.safetyCheck.noAnswer';

    return ColoredBox(
      color: context.colors.scrim.withValues(alpha: 0.54),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20.fx),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: context.tr('$key.title'),
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24.fx),
                child: Padding(
                  padding: EdgeInsets.all(24.fx),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        container: true,
                        child: Text(
                          context.tr('$key.title'),
                          textAlign: TextAlign.center,
                          style: context.texts.headlineSmall?.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Gap(12.fx),
                      Text(
                        context.tr('$key.body'),
                        textAlign: TextAlign.center,
                        style: context.texts.bodyMedium?.copyWith(
                          color: colors.text,
                          height: 1.6,
                        ),
                      ),
                      Gap(20.fx),
                      if (!asking)
                        EscalationStatus(journeyId: widget.check.journeyId),
                      if (asking)
                        SafetyCheckAnswer(
                          left: widget.check.deadline.difference(widget.now()),
                          total: widget.total,
                          confirming: widget.confirming,
                          onSafe: widget.onSafe,
                        )
                      else
                        AppPrimaryButton(
                          label: context.tr(
                            'journeys.safetyCheck.noAnswer.close',
                          ),
                          outlined: true,
                          onPressed: widget.onClose,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
