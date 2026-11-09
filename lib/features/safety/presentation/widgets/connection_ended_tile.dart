import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_labels.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_initial.dart';

/// A connection that is over, by either person: said once, then clearable.
class ConnectionEndedTile extends StatelessWidget {
  const ConnectionEndedTile({
    required this.connection,
    required this.onClear,
    super.key,
  });

  final ConnectionModel connection;

  /// Null while something else is under way.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final DateTime? at = connection.revokedAt;

    return ConnectionCard(
      actions: <Widget>[
        ConnectionCardAction(
          label: context.tr('safety.connections.ended.clear'),
          icon: Icons.close_rounded,
          onPressed: onClear,
        ),
      ],
      child: Row(
        children: <Widget>[
          ContactInitial(name: connection.displayName),
          Gap(12.fx),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.fx,
              children: <Widget>[
                Text(
                  connection.displayName,
                  style: context.texts.titleSmall?.copyWith(color: colors.text),
                ),
                Text(
                  at == null
                      ? ConnectionLabels.status(context, connection.status)
                      : context.tr(
                          'safety.connections.ended.on',
                          namedArgs: <String, String>{
                            'date': ConnectionLabels.date(context, at),
                          },
                        ),
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
