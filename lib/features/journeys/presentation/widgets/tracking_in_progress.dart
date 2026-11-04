import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_duration.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_location.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_stat.dart';

/// The recording in progress: speed, distance and duration, where the phone
/// is, how the route stands with the account, and — when the recording is
/// blocked — what to do about it.
class TrackingInProgress extends StatelessWidget {
  const TrackingInProgress({
    required this.snapshot,
    required this.since,
    required this.onAllow,
    required this.onSettings,
    super.key,
  });

  final TrackingSnapshot snapshot;

  /// When the journey started (UTC).
  final DateTime since;
  final VoidCallback onAllow;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final TrackingStatus status = snapshot.status;
    final bool blocked =
        status == TrackingStatus.permissionRequired ||
        status == TrackingStatus.preciseOff ||
        status == TrackingStatus.locationOff;
    final TextStyle? quiet = context.texts.bodySmall?.copyWith(
      color: context.appColors.textMuted,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _Speed(reading: snapshot.speed)),
            Expanded(
              child: TrackingStat(
                label: context.tr('journeys.tracking.distance'),
                value: TrackingLabels.distance(
                  context,
                  snapshot.distanceMeters,
                ),
              ),
            ),
            Expanded(child: TrackingDuration(since: since)),
          ],
        ),
        Gap(16.fx),
        TrackingLocation(
          point: snapshot.last,
          fresh:
              status == TrackingStatus.active ||
              status == TrackingStatus.weakSignal,
        ),
        if (snapshot.sync != RouteSync.none) ...<Widget>[
          Gap(10.fx),
          Text(
            context.tr('journeys.tracking.sync.${snapshot.sync.name}'),
            style: quiet,
          ),
        ],
        if (blocked) ...<Widget>[
          Gap(14.fx),
          Text(
            context.tr('journeys.tracking.blocked.${status.name}'),
            style: quiet?.copyWith(color: context.appColors.text),
          ),
          Gap(12.fx),
          AppPrimaryButton(
            label: context.tr(
              status == TrackingStatus.permissionRequired
                  ? 'journeys.tracking.needs.denied.action'
                  : 'journeys.tracking.needs.serviceOff.action',
            ),
            outlined: true,
            onPressed: status == TrackingStatus.permissionRequired
                ? onAllow
                : onSettings,
          ),
        ],
      ],
    );
  }
}

/// Current, last known, or no speed — never a stale figure passed off as
/// the current one.
class _Speed extends StatelessWidget {
  const _Speed({required this.reading});

  final SpeedReading reading;

  @override
  Widget build(BuildContext context) {
    final double? kmh = reading.kmh;
    return TrackingStat(
      label: context.tr('journeys.tracking.speed'),
      value: kmh == null ? '—' : TrackingLabels.speed(context, kmh),
      caption: context.tr(
        kmh == null
            ? 'journeys.tracking.speedUnavailable'
            : reading.current
            ? 'journeys.tracking.speedCurrent'
            : 'journeys.tracking.speedLastKnown',
      ),
    );
  }
}
