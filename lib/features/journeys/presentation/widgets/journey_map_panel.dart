import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_map_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_map_figures.dart';
import 'package:safe_ride/core/shared_widgets/status_chip.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_labels.dart';

/// The journey at a glance, under the map: where from and to, the status, and
/// the figures. Remaining distance and arrival appear only when the position
/// sits on a planned route; an invented estimate is worse than none.
class JourneyMapPanel extends StatelessWidget {
  const JourneyMapPanel({required this.state, super.key});

  final JourneyMapState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final JourneyModel? journey = state.journey;

    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.text.withValues(alpha: 0.25),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.fx)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // The map stays the main thing, even at large text.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenSide,
              14.fx,
              AppSpacing.screenSide,
              12.fx,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  journey == null
                      ? ''
                      : context.tr(
                          'journeys.route',
                          namedArgs: <String, String>{
                            'from': JourneyLabels.place(journey.origin),
                            'to': JourneyLabels.place(journey.destination),
                          },
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(8.fx),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusChip(
                    label: MapLabels.status(context, state.status),
                    color: MapLabels.tone(colors, state.status),
                  ),
                ),
                Gap(12.fx),
                JourneyMapFigures(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
