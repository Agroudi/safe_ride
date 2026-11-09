import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/planned_route.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_search_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';

/// What a search found, or why it found nothing.
class PlaceSearchResults extends StatelessWidget {
  const PlaceSearchResults({
    required this.state,
    required this.onPick,
    super.key,
  });

  final PlaceSearchState state;
  final ValueChanged<JourneyPlace> onPick;

  String _message(BuildContext context) => context.tr(switch (state) {
    PlaceSearchState(status: PlaceSearchStatus.empty) =>
      'journeys.map.search.empty',
    PlaceSearchState(failure: MapFailureCode.offline) =>
      'journeys.map.search.offline',
    _ => 'journeys.map.search.failed',
  });

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.text.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16.fx),
      clipBehavior: Clip.antiAlias,
      child: state.status == PlaceSearchStatus.results
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 280.fx),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final JourneyPlace p in state.places)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.place_outlined,
                        color: colors.accentText,
                      ),
                      title: Text(
                        JourneyLabels.place(p.name),
                        style: context.texts.bodyMedium?.copyWith(
                          color: colors.text,
                        ),
                      ),
                      subtitle: p.address == null
                          ? null
                          : Text(
                              JourneyLabels.place(p.address!),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodySmall?.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                      onTap: () => onPick(p),
                    ),
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.all(14.fx),
              child: Text(
                _message(context),
                style: context.texts.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
    );
  }
}
