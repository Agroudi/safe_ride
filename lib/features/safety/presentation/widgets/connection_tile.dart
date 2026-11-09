import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/status_chip.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_labels.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_initial.dart';

/// Someone connected: who, since when, and that this opens nothing by itself.
class ConnectionTile extends StatelessWidget {
  const ConnectionTile({
    required this.connection,
    required this.onManage,
    required this.onRemove,
    super.key,
  });

  final ConnectionModel connection;
  final VoidCallback onManage;

  /// Null while something else is under way.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TextStyle? small = context.texts.bodySmall?.copyWith(
      color: colors.textMuted,
    );

    return ConnectionCard(
      actions: <Widget>[
        ConnectionCardAction(
          label: context.tr('safety.connections.manage'),
          icon: Icons.tune_rounded,
          onPressed: onManage,
        ),
        ConnectionCardAction(
          label: context.tr('safety.connections.remove'),
          icon: Icons.person_remove_rounded,
          onPressed: onRemove,
          destructive: true,
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ContactInitial(name: connection.displayName),
          Gap(12.fx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3.fx,
              children: <Widget>[
                Text(
                  connection.displayName,
                  style: context.texts.titleSmall?.copyWith(color: colors.text),
                ),
                StatusChip(
                  label: ConnectionLabels.status(context, connection.status),
                  color: ConnectionLabels.tone(colors, connection.status),
                ),
                Text(
                  context.tr(
                    'safety.connections.since',
                    namedArgs: <String, String>{
                      'date': ConnectionLabels.date(
                        context,
                        connection.acceptedAt,
                      ),
                    },
                  ),
                  style: small,
                ),
                Text(
                  context.tr('safety.connections.nothingShared'),
                  style: small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
