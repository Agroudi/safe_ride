import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/data/models/location_fix.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_picker_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_labels.dart';

/// What is under the pin, "Use my location", and Confirm.
class PlacePickerCard extends StatelessWidget {
  const PlacePickerCard({
    required this.state,
    required this.onConfirm,
    required this.onLocate,
    required this.onSettings,
    super.key,
  });

  final PlacePickerState state;
  final VoidCallback onConfirm;
  final VoidCallback onLocate;
  final ValueChanged<LocationAccess> onSettings;

  String _title(BuildContext context) {
    final JourneyPlace? place = state.place;
    if (place != null) return JourneyLabels.place(place.name);
    if (state.naming) return context.tr('journeys.map.naming');
    return context.tr(
      state.point == null ? 'journeys.map.choose' : 'journeys.map.pinned',
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? address = state.place?.address;
    final LocationAccess? problem = state.locationProblem;

    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.text.withValues(alpha: 0.25),
      borderRadius: BorderRadiusDirectional.vertical(
        top: Radius.circular(22.fx),
      ).resolve(Directionality.of(context)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            16.fx,
            AppSpacing.screenSide,
            14.fx,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _title(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (address != null) ...<Widget>[
                Gap(2.fx),
                Text(
                  JourneyLabels.place(address),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
              if (problem != null) ...<Widget>[
                Gap(8.fx),
                Text(
                  context.tr('journeys.map.location.${problem.name}'),
                  style: context.texts.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => onSettings(problem),
                  child: Text(context.tr('journeys.map.location.settings')),
                ),
              ],
              Gap(12.fx),
              AppPrimaryButton(
                label: context.tr('journeys.map.useLocation'),
                outlined: true,
                busy: state.locating,
                onPressed: onLocate,
              ),
              Gap(10.fx),
              AppPrimaryButton(
                label: context.tr('journeys.map.confirm'),
                onPressed: state.point == null ? null : onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
