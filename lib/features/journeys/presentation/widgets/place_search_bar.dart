import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_search_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_search_results.dart';

/// The search field on the map, and what it found under it.
class PlaceSearchBar extends StatelessWidget {
  const PlaceSearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.onPick,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<JourneyPlace> onPick;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;

    return BlocBuilder<PlaceSearchCubit, PlaceSearchState>(
      builder: (BuildContext context, PlaceSearchState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: colors.surface,
            elevation: 3,
            shadowColor: colors.text.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16.fx),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: context.texts.bodyMedium?.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted),
                suffixIcon: state.status == PlaceSearchStatus.searching
                    ? Padding(
                        padding: EdgeInsets.all(14.fx),
                        child: const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('journeys.map.search.clear'),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.textMuted,
                        ),
                        onPressed: onClear,
                      ),
              ),
            ),
          ),
          if (state.status != PlaceSearchStatus.idle &&
              state.status != PlaceSearchStatus.searching) ...<Widget>[
            Gap(6.fx),
            PlaceSearchResults(state: state, onPick: onPick),
          ],
        ],
      ),
    );
  }
}
