import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/shared_view.dart';
import 'package:safe_ride/features/journeys/logic/cubit/shared_view_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';
import 'package:safe_ride/core/shared_widgets/status_chip.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/share_labels.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/tracking_labels.dart';

/// Under the recipient's map: what is shared, how far to trust it, and when
/// it was last updated.
class SharedViewPanel extends StatelessWidget {
  const SharedViewPanel({required this.state, super.key});

  final SharedViewState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final SharedView? view = state.view;
    if (view == null) return const SizedBox.shrink();
    final SharedViewLabel label = SharedViewLabel.of(
      state.liveness,
      offline: state.offline,
    );
    final DateTime? at = view.locationAt;
    final double? metres = view.distanceMeters;
    final SharedPlace? from = view.origin;
    final SharedPlace? to = view.destination;
    final TextStyle? muted = context.texts.bodySmall?.copyWith(
      color: colors.textMuted,
    );

    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.text.withValues(alpha: 0.25),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.fx)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
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
                  from != null && to != null
                      ? context.tr(
                          'journeys.route',
                          namedArgs: <String, String>{
                            'from': JourneyLabels.place(from.name),
                            'to': JourneyLabels.place(to.name),
                          },
                        )
                      : context.tr(
                          view.isJourney
                              ? 'sharing.view.journey'
                              : 'sharing.view.location',
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
                    label: ShareLabels.liveness(context, label),
                    color: ShareLabels.livenessTone(colors, label),
                  ),
                ),
                if (at != null) ...<Widget>[
                  Gap(8.fx),
                  Text(
                    context.tr(
                      'sharing.view.updated',
                      namedArgs: <String, String>{
                        'time': MapLabels.clock(context, at),
                      },
                    ),
                    style: muted,
                  ),
                ],
                if (metres != null) ...<Widget>[
                  Gap(2.fx),
                  Text(
                    context.tr(
                      'sharing.view.travelled',
                      namedArgs: <String, String>{
                        'distance': TrackingLabels.distance(context, metres),
                      },
                    ),
                    style: muted,
                  ),
                ],
                Gap(2.fx),
                Text(
                  context.tr(
                    'sharing.view.ends',
                    namedArgs: <String, String>{
                      'time': MapLabels.clock(context, view.expiresAt),
                    },
                  ),
                  style: muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
