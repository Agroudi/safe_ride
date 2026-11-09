import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/track_point.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_map_panel.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_button.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_credit.dart';

/// What sits at the foot of the live map: the controls over the panel.
class JourneyMapFooter extends StatelessWidget {
  const JourneyMapFooter({
    required this.following,
    required this.onZoom,
    required this.onRecenter,
    super.key,
  });

  final bool following;
  final ValueChanged<double> onZoom;
  final ValueChanged<TrackPoint> onRecenter;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<JourneyMapCubit, JourneyMapState>(
        builder: (BuildContext context, JourneyMapState state) {
          final TrackPoint? now = state.current;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              JourneyMapControls(
                following: following,
                onZoomIn: () => onZoom(1),
                onZoomOut: () => onZoom(-1),
                onRecenter: now == null ? null : () => onRecenter(now),
              ),
              JourneyMapPanel(state: state),
            ],
          );
        },
      );
}

/// Beside the buttons and above the panel, so nothing covers the credit.
class JourneyMapControls extends StatelessWidget {
  const JourneyMapControls({
    required this.following,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    super.key,
  });

  final bool following;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? recenter = onRecenter;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 6.fx,
        end: 12.fx,
        bottom: 8.fx,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: MapCredit(extra: 'OSRM'),
            ),
          ),
          Gap(8.fx),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MapButton(
                icon: Icons.add_rounded,
                label: context.tr('journeys.map.zoomIn'),
                onPressed: onZoomIn,
              ),
              Gap(8.fx),
              MapButton(
                icon: Icons.remove_rounded,
                label: context.tr('journeys.map.zoomOut'),
                onPressed: onZoomOut,
              ),
              if (recenter != null) ...<Widget>[
                Gap(8.fx),
                MapButton(
                  icon: following
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  label: context.tr('journeys.map.recenter'),
                  active: following,
                  onPressed: recenter,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
