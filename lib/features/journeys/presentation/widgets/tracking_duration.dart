import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_stat.dart';

/// How long the journey has been in progress, refreshed every
/// [refreshEvery] — a figure that changes, not an animation.
class TrackingDuration extends StatefulWidget {
  const TrackingDuration({required this.since, super.key});

  /// When the journey started (UTC).
  final DateTime since;

  static const Duration refreshEvery = Duration(seconds: 20);

  @override
  State<TrackingDuration> createState() => _TrackingDurationState();
}

class _TrackingDurationState extends State<TrackingDuration> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      TrackingDuration.refreshEvery,
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrackingStat(
    label: context.tr('journeys.tracking.duration'),
    value: TrackingLabels.duration(
      context,
      DateTime.now().toUtc().difference(widget.since),
    ),
  );
}
