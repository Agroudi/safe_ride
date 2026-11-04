import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/logic/states/tracking_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_status_chip.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_access.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_in_progress.dart';

/// The journey's route recording, under its places: a titled card whose
/// body follows [state]. Draws nothing while there is nothing to say.
class TrackingCard extends StatelessWidget {
  const TrackingCard({
    required this.state,
    required this.since,
    required this.onAllow,
    required this.onSettings,
    super.key,
  });

  final TrackingState state;

  /// When the journey started (UTC).
  final DateTime since;
  final VoidCallback onAllow;
  final ValueChanged<LocationAccess> onSettings;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final TrackingState s = state;
    if (s is TrackingIdle) return const SizedBox.shrink();
    final TextStyle? quiet = context.texts.bodySmall?.copyWith(
      color: colors.textMuted,
      height: 1.6,
    );

    return Container(
      padding: EdgeInsets.all(18.fx),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20.fx),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  container: true,
                  child: Text(
                    context.tr('journeys.tracking.title'),
                    style: context.texts.titleSmall?.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (s case TrackingLive(:final snapshot))
                JourneyStatusChip(
                  label: TrackingLabels.status(context, snapshot.status),
                  color: TrackingLabels.tone(colors, snapshot.status),
                )
              else if (s is TrackingRecorded)
                JourneyStatusChip(
                  label: context.tr('journeys.tracking.status.stopped'),
                  color: colors.textMuted,
                ),
            ],
          ),
          Gap(14.fx),
          switch (s) {
            TrackingLive(:final snapshot) => TrackingInProgress(
              snapshot: snapshot,
              since: since,
              onAllow: onAllow,
              onSettings: () => onSettings(
                snapshot.status == TrackingStatus.locationOff
                    ? LocationAccess.serviceOff
                    : LocationAccess.approximate,
              ),
            ),
            TrackingNeedsAccess(:final access) => TrackingAccess(
              access: access,
              onAllow: onAllow,
              onSettings: () => onSettings(access),
            ),
            TrackingElsewhere() => Text(
              context.tr('journeys.tracking.elsewhere'),
              style: quiet,
            ),
            TrackingFailed() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(context.tr('journeys.tracking.failed'), style: quiet),
                Gap(10.fx),
                AppPrimaryButton(
                  label: context.tr('journeys.escalation.retry'),
                  outlined: true,
                  onPressed: onAllow,
                ),
              ],
            ),
            TrackingRecorded(:final summary) => Text(
              summary == null || summary.pointCount == 0
                  ? context.tr('journeys.tracking.notRecorded')
                  : context.tr(
                      'journeys.tracking.recorded',
                      namedArgs: <String, String>{
                        'value': TrackingLabels.kilometres(
                          context,
                          summary.distanceMeters,
                        ),
                      },
                    ),
              style: quiet,
            ),
            TrackingIdle() => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}
