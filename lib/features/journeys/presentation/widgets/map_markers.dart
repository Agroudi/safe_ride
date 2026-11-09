import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// The two ends of a journey on a map.
enum MapPlaceKind { start, destination }

/// A journey's end as a map marker, tip on the place.
Marker placeMarker(LatLng point, MapPlaceKind kind, String label) => Marker(
  point: point,
  width: 44,
  height: 52,
  alignment: Alignment.topCenter,
  child: PlacePin(kind: kind, label: label),
);

/// The start is a ring, the destination a flag: told apart by shape as well
/// as colour.
class PlacePin extends StatelessWidget {
  const PlacePin({required this.kind, required this.label, super.key});

  final MapPlaceKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final bool start = kind == MapPlaceKind.start;

    return Semantics(
      container: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: start ? colors.secondary : colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 3),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.text.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              start ? Icons.radio_button_checked_rounded : Icons.flag_rounded,
              size: 18,
              color: start ? colors.onSecondary : colors.onPrimary,
            ),
          ),
          Container(
            width: 3,
            height: 12,
            color: start ? colors.secondary : colors.primary,
          ),
        ],
      ),
    );
  }
}

/// Where the phone is: a dot, and an arrow only when the direction is known.
class CurrentLocationDot extends StatelessWidget {
  const CurrentLocationDot({required this.label, this.heading, super.key});

  final String label;

  /// Degrees from north, when reliable.
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final double? direction = heading;

    return Semantics(
      container: true,
      label: label,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: colors.info,
          shape: BoxShape.circle,
          border: Border.all(color: colors.surface, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.info.withValues(alpha: 0.45),
              blurRadius: 10,
            ),
          ],
        ),
        child: direction == null
            ? null
            : Transform.rotate(
                angle: direction * math.pi / 180,
                // Straight up at 0 degrees: north.
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 15,
                  color: colors.onStatus,
                ),
              ),
      ),
    );
  }
}

/// [PlacePin] standing on the middle of the map, tip on its centre. Taps go
/// through it to the map.
class CentredPlacePin extends StatelessWidget {
  const CentredPlacePin({required this.kind, required this.label, super.key});

  final MapPlaceKind kind;
  final String label;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Center(
      child: Transform.translate(
        offset: const Offset(0, -26),
        child: PlacePin(kind: kind, label: label),
      ),
    ),
  );
}
