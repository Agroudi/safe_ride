import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The frame of a connection or an invite, with a row of small actions.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    required this.child,
    this.actions = const <Widget>[],
    super.key,
  });

  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(14.fx, 14.fx, 14.fx, 6.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          child,
          // A `Wrap`: at large text, or in a longer language, they stack.
          Wrap(alignment: WrapAlignment.end, children: actions),
        ],
      ),
    );
  }
}

/// One small action on a [ConnectionCard].
class ConnectionCardAction extends StatelessWidget {
  const ConnectionCardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final String label;
  final IconData icon;

  /// Null while something else is under way.
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18.fx),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: destructive ? colors.error : colors.accentText,
      ),
    );
  }
}
