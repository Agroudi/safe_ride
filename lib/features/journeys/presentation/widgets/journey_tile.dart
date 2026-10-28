import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_tile_body.dart';

/// One journey in a list: where to, from where, when it leaves, and its
/// status. The row opens the journey and is read as one item; a planned
/// journey also gets a "more" menu with Cancel ([onCancel]), its own
/// button outside the row's tap.
class JourneyTile extends StatelessWidget {
  const JourneyTile({
    required this.origin,
    required this.destination,
    required this.dateLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    this.onCancel,
    this.cancelLabel,
    this.moreLabel,
    super.key,
  });

  final String origin;
  final String destination;
  final String dateLabel;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  /// Null: no menu (the journey is closed, or the list offers no actions).
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final String? moreLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final VoidCallback? cancel = onCancel;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.fx),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          Expanded(
            child: MergeSemantics(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    14.fx,
                    14.fx,
                    cancel == null ? 14.fx : 4.fx,
                    14.fx,
                  ),
                  child: JourneyTileBody(
                    origin: origin,
                    destination: destination,
                    dateLabel: dateLabel,
                    statusLabel: statusLabel,
                    statusColor: statusColor,
                  ),
                ),
              ),
            ),
          ),
          if (cancel != null)
            PopupMenuButton<void>(
              tooltip: moreLabel,
              icon: Icon(Icons.more_vert_rounded, color: colors.textMuted),
              itemBuilder: (_) => <PopupMenuEntry<void>>[
                PopupMenuItem<void>(onTap: cancel, child: Text(cancelLabel!)),
              ],
            ),
        ],
      ),
    );
  }
}
