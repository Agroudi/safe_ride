import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';

/// How the map's words and estimates read.
abstract final class MapLabels {
  static String status(BuildContext context, MapTrackingStatus status) =>
      context.tr('journeys.map.status.${status.name}');

  static Color tone(AppColors colors, MapTrackingStatus status) =>
      switch (status) {
        MapTrackingStatus.recording ||
        MapTrackingStatus.resumed => colors.success,
        MapTrackingStatus.weakSignal ||
        MapTrackingStatus.unavailable => colors.warning,
        MapTrackingStatus.interrupted => colors.error,
        MapTrackingStatus.completed => colors.textMuted,
      };

  /// A clock time in the locale's digits: an arrival is a time of day.
  static String clock(BuildContext context, DateTime at) => DateFormat.jm(
    LocaleNumbers.tag(context.locale.languageCode),
  ).format(at.toLocal());

  /// Why a route cannot be shown. The places are never lost with it.
  static String routeFailure(BuildContext context, MapFailureCode code) =>
      context.tr(switch (code) {
        MapFailureCode.noRoute => 'journeys.map.route.noRoute',
        MapFailureCode.offline => 'journeys.map.route.offline',
        MapFailureCode.unavailable ||
        MapFailureCode.cancelled => 'journeys.map.route.unavailable',
      });

  /// "About 14.2 km, 25 min", or the distance alone without an estimate.
  static String routeSummary(
    BuildContext context, {
    required double metres,
    double? seconds,
  }) {
    final String distance = TrackingLabels.distance(context, metres);
    return seconds == null
        ? context.tr(
            'journeys.map.route.distanceOnly',
            namedArgs: <String, String>{'distance': distance},
          )
        : context.tr(
            'journeys.map.route.summary',
            namedArgs: <String, String>{
              'distance': distance,
              'duration': TrackingLabels.duration(
                context,
                Duration(seconds: seconds.round()),
              ),
            },
          );
  }
}
