import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One reading, said as it is: "Current location" only while it is fresh,
/// else "Last known location" with its age (and a warning once it is old),
/// the coordinates as an operator would read them, and how far off they may
/// be.
class LocationReadingLines extends StatelessWidget {
  const LocationReadingLines({
    required this.reading,
    required this.now,
    super.key,
  });

  final PositionReading reading;
  final DateTime now;

  /// "24.71362, 46.67531": Latin digits, five decimals (about a metre),
  /// left to right in both languages.
  static String coordinates(PositionReading r) =>
      '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}';

  String _age(BuildContext context) {
    final Duration age = reading.age(now);
    final (String unit, int count) = age.inSeconds < 60
        ? ('seconds', age.inSeconds)
        : age.inMinutes < 60
        ? ('minutes', age.inMinutes)
        : ('hours', age.inHours);
    return context.plural(
      'safety.location.age.$unit',
      count,
      namedArgs: <String, String>{
        'count': LocaleNumbers.decimal(
          context.locale.languageCode,
        ).format(count),
      },
    );
  }

  String _accuracy(BuildContext context) {
    final String meters = LocaleNumbers.decimal(
      context.locale.languageCode,
    ).format((reading.accuracy ?? 0).round());
    return switch (reading.quality) {
      PositionAccuracy.unknown => context.tr(
        'safety.location.accuracy.unknown',
      ),
      PositionAccuracy.poor => context.tr(
        'safety.location.accuracy.poor',
        namedArgs: <String, String>{'meters': meters},
      ),
      PositionAccuracy.good || PositionAccuracy.rough => context.tr(
        'safety.location.accuracy.within',
        namedArgs: <String, String>{'meters': meters},
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final PositionFreshness freshness = reading.freshness(now);
    final bool current = freshness == PositionFreshness.current;
    final TextStyle? muted = context.texts.bodySmall?.copyWith(
      color: colors.textMuted,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.tr(
            current ? 'safety.location.current' : 'safety.location.lastKnown',
          ),
          style: context.texts.titleSmall?.copyWith(
            color: current ? colors.success : colors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(_age(context), style: muted),
        Gap(8.fx),
        SelectableText(
          coordinates(reading),
          textDirection: TextDirection.ltr,
          textAlign: context.isRtl ? TextAlign.right : TextAlign.left,
          style: context.texts.titleMedium?.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(4.fx),
        Text(
          _accuracy(context),
          style: reading.quality == PositionAccuracy.poor
              ? muted?.copyWith(color: colors.error)
              : muted,
        ),
        if (freshness == PositionFreshness.stale) ...<Widget>[
          Gap(6.fx),
          Text(
            context.tr('safety.location.stale'),
            style: muted?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}
