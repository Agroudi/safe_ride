import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';

/// Under a place's field: choose it on the map, or that it already is.
class PlacePinButton extends StatelessWidget {
  const PlacePinButton({
    required this.kind,
    required this.pinned,
    required this.onPressed,
    super.key,
  });

  final MapPlaceKind kind;
  final bool pinned;
  final ValueChanged<MapPlaceKind> onPressed;

  /// Opens the picker on [current]; the place chosen, or null if left.
  static Future<JourneyPlace?> pick(
    BuildContext context,
    MapPlaceKind kind,
    JourneyPlace? current,
  ) => context.pushNamed<JourneyPlace>(
    AppRoutes.pickPlace,
    extra: <String, Object?>{'kind': kind.name, 'place': current?.toJson()},
  );

  String get _label => pinned
      ? 'journeys.map.onMap'
      : kind == MapPlaceKind.start
      ? 'journeys.map.pickStart'
      : 'journeys.map.pickDestination';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        button: true,
        child: InkWell(
          onTap: () => onPressed(kind),
          borderRadius: BorderRadius.circular(10.fx),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: math.max(44, 44.fx)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  pinned
                      ? Icons.check_circle_rounded
                      : Icons.add_location_alt_outlined,
                  size: 18.fx,
                  color: colors.accentText,
                ),
                Gap(6.fx),
                Flexible(
                  child: Text(
                    context.tr(_label),
                    style: context.texts.labelMedium?.copyWith(
                      color: colors.accentText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
