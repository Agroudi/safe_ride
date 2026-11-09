import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_picker_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_search_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_search_bar.dart';

/// Back, and the search over the map. Searches near the pin.
class PlacePickerTopBar extends StatefulWidget {
  const PlacePickerTopBar({
    required this.hint,
    required this.onPick,
    super.key,
  });

  final String hint;
  final ValueChanged<JourneyPlace> onPick;

  @override
  State<PlacePickerTopBar> createState() => _PlacePickerTopBarState();
}

class _PlacePickerTopBarState extends State<PlacePickerTopBar> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _query(String text) {
    setState(() {}); // The clear button follows the text.
    context.read<PlaceSearchCubit>().query(
      text,
      languageCode: context.locale.languageCode,
      near: context.read<PlacePickerCubit>().state.point,
    );
  }

  void _clear() {
    _search.clear();
    setState(() {});
    context.read<PlaceSearchCubit>().clear();
  }

  void _picked(JourneyPlace place) {
    _clear();
    widget.onPick(place);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.screenSide,
        vertical: 10.fx,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppBackButton(),
          Gap(10.fx),
          Expanded(
            child: PlaceSearchBar(
              controller: _search,
              hint: widget.hint,
              onChanged: _query,
              onClear: _clear,
              onPick: _picked,
            ),
          ),
        ],
      ),
    ),
  );
}
