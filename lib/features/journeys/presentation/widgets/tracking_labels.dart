import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/data/models/tracking_snapshot.dart';

/// How the route recording reads: status words and colours, and numbers in
/// the locale's digits.
abstract final class TrackingLabels {
  static String status(BuildContext context, TrackingStatus status) =>
      context.tr('journeys.tracking.status.${status.name}');

  static Color tone(AppColors colors, TrackingStatus status) =>
      switch (status) {
        TrackingStatus.active => colors.success,
        TrackingStatus.starting => colors.info,
        TrackingStatus.weakSignal || TrackingStatus.noSignal => colors.warning,
        TrackingStatus.permissionRequired ||
        TrackingStatus.preciseOff ||
        TrackingStatus.locationOff => colors.error,
      };

  /// Whole km/h: a decimal would claim a precision GPS does not have.
  static String speed(BuildContext context, double kmh) => context.tr(
    'journeys.tracking.speedValue',
    namedArgs: <String, String>{'value': _format(context, '0', kmh)},
  );

  /// Kilometres: two decimals under 10 km, one above.
  static String distance(BuildContext context, double metres) => context.tr(
    'journeys.tracking.distanceValue',
    namedArgs: <String, String>{'value': kilometres(context, metres)},
  );

  static String kilometres(BuildContext context, double metres) =>
      _format(context, metres < 10000 ? '0.00' : '0.0', metres / 1000);

  static String duration(BuildContext context, Duration elapsed) {
    final Duration d = elapsed.isNegative ? Duration.zero : elapsed;
    final String minutes = _format(context, '0', d.inMinutes % 60);
    return d.inHours == 0
        ? context.tr(
            'journeys.tracking.durationMinutes',
            namedArgs: <String, String>{'minutes': minutes},
          )
        : context.tr(
            'journeys.tracking.durationHours',
            namedArgs: <String, String>{
              'hours': _format(context, '0', d.inHours),
              'minutes': minutes,
            },
          );
  }

  /// Latitude and longitude to five decimals (about a metre).
  static String coordinates(BuildContext context, TrackPoint point) {
    final String separator = context.locale.languageCode == 'ar' ? '، ' : ', ';
    return '${_format(context, '0.00000', point.lat)}$separator'
        '${_format(context, '0.00000', point.lng)}';
  }

  static String accuracy(BuildContext context, double metres) => context.tr(
    'journeys.tracking.accuracy',
    namedArgs: <String, String>{'value': _format(context, '0', metres)},
  );

  static String _format(BuildContext context, String pattern, num value) =>
      NumberFormat(
        pattern,
        LocaleNumbers.tag(context.locale.languageCode),
      ).format(value);
}
