import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_initial.dart';

/// One person on Get help: initial, name, how the user knows them, and —
/// for a saved number — its [actions] below, so they wrap at large text
/// instead of squeezing the name.
class HelpPerson extends StatelessWidget {
  const HelpPerson({required this.name, this.detail, this.actions, super.key});

  final String name;
  final String? detail;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final Widget? below = actions;

    return Container(
      padding: EdgeInsets.all(12.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ContactInitial(name: name),
              Gap(12.fx),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: context.texts.titleSmall?.copyWith(
                        color: colors.text,
                      ),
                    ),
                    if (detail case final String d)
                      Text(
                        d,
                        style: context.texts.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (below != null) ...<Widget>[Gap(6.fx), below],
        ],
      ),
    );
  }
}
