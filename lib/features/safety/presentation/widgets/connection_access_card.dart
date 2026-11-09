import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_access.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';

/// What this connection allows, from `ConnectionAccess`: nothing here is a
/// switch, because nothing can be turned on through a connection.
class ConnectionAccessCard extends StatelessWidget {
  const ConnectionAccessCard({required this.connection, super.key});

  final ConnectionModel connection;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(14.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12.fx,
        children: <Widget>[
          for (final ConnectionAccessKind kind in ConnectionAccessKind.values)
            _Row(
              allowed: ConnectionAccess.allows(connection, kind),
              title: context.tr('safety.connections.access.${kind.name}.title'),
              body: context.tr('safety.connections.access.${kind.name}.body'),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.allowed, required this.title, required this.body});

  final bool allowed;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            allowed ? Icons.check_circle_rounded : Icons.block_rounded,
            size: 20.fx,
            color: allowed ? colors.success : colors.textMuted,
          ),
          Gap(10.fx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.fx,
              children: <Widget>[
                Text(
                  title,
                  style: context.texts.titleSmall?.copyWith(color: colors.text),
                ),
                Text(
                  body,
                  style: context.texts.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
