import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/status_chip.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/data/models/connection_invite_model.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_labels.dart';

/// An invite nobody accepted: waiting, with its link, or expired.
class ConnectionInviteTile extends StatelessWidget {
  const ConnectionInviteTile({
    required this.invite,
    required this.status,
    required this.onCopy,
    required this.onShare,
    required this.onCancel,
    super.key,
  });

  final ConnectionInviteModel invite;

  /// [ConnectionInviteModel.statusAt] now.
  final ConnectionStatus status;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  /// Null while something else is under way.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool waiting = status == ConnectionStatus.pending;

    return ConnectionCard(
      actions: <Widget>[
        if (waiting) ...<Widget>[
          ConnectionCardAction(
            label: context.tr('safety.connections.invites.copy'),
            icon: Icons.copy_rounded,
            onPressed: onCopy,
          ),
          ConnectionCardAction(
            label: context.tr('safety.connections.invites.share'),
            icon: Icons.ios_share_rounded,
            onPressed: onShare,
          ),
        ],
        ConnectionCardAction(
          label: context.tr(
            waiting
                ? 'safety.connections.invites.cancel'
                : 'safety.connections.invites.clear',
          ),
          icon: Icons.close_rounded,
          onPressed: onCancel,
          destructive: waiting,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6.fx,
        children: <Widget>[
          StatusChip(
            label: ConnectionLabels.status(context, status),
            color: ConnectionLabels.tone(colors, status),
          ),
          Text(
            context.tr(
              waiting
                  ? 'safety.connections.invites.expires'
                  : 'safety.connections.invites.expired',
              namedArgs: <String, String>{
                'date': ConnectionLabels.date(context, invite.expiresAt),
              },
            ),
            style: context.texts.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
