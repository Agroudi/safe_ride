import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// [MapNotice] for as long as the tiles cannot be reached.
class MapTilesNotice extends StatelessWidget {
  const MapTilesNotice({
    required this.reachable,
    required this.failed,
    required this.onRetry,
    super.key,
  });

  final ValueListenable<bool> reachable;

  /// The style itself did not load, so there is something to try again.
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: reachable,
    builder: (_, bool ok, _) => !ok || failed
        ? Center(
            child: MapNotice(
              text: context.tr('journeys.map.offline'),
              onRetry: failed ? onRetry : null,
              retryLabel: context.tr('journeys.map.retry'),
            ),
          )
        : const SizedBox.shrink(),
  );
}

/// A short note floating on a map: it is offline, and what still works.
class MapNotice extends StatelessWidget {
  const MapNotice({
    required this.text,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  final String text;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final VoidCallback? retry = onRetry;

    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.text.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14.fx),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.fx, vertical: 8.fx),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, size: 18.fx, color: colors.warning),
            Gap(8.fx),
            Flexible(
              child: Text(
                text,
                style: context.texts.bodySmall?.copyWith(color: colors.text),
              ),
            ),
            if (retry != null) ...<Widget>[
              Gap(8.fx),
              TextButton(onPressed: retry, child: Text(retryLabel ?? '')),
            ],
          ],
        ),
      ),
    );
  }
}
