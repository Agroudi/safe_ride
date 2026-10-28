import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/departure_field.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_chips.dart';

/// A journey's three fields, inside the page's `Form`: where from, where to
/// (with the user's own earlier places offered back), and when. One widget
/// for planning and for editing, so the two can never ask differently.
class JourneyForm extends StatelessWidget {
  const JourneyForm({
    required this.from,
    required this.to,
    required this.departsAt,
    required this.onDeparture,
    required this.past,
    this.keptDeparture,
    super.key,
  });

  final TextEditingController from;
  final TextEditingController to;

  /// Local time; null until chosen.
  final DateTime? departsAt;
  final ValueChanged<DateTime> onDeparture;

  /// The account's journeys, for the recent-place chips.
  final List<JourneyModel> past;

  /// Editing: the stored departure (local), valid even once it has passed.
  final DateTime? keptDeparture;

  /// The last few distinct places, newest first.
  static List<String> _places(List<JourneyModel> journeys, bool origins) {
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final JourneyModel j in journeys) {
      final String p = origins ? j.origin : j.destination;
      if (seen.add(p.toLowerCase()) && out.length < 3) out.add(p);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final Validators validate = Validators.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          label: context.tr('journeys.plan.fromLabel'),
          hint: context.tr('journeys.plan.fromHint'),
          controller: from,
          validator: validate.place,
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.next,
        ),
        PlaceChips(
          label: context.tr('journeys.plan.recent'),
          places: _places(past, true),
          onPick: (String p) => from.text = p,
        ),
        Gap(18.fx),
        AppTextField(
          label: context.tr('journeys.plan.toLabel'),
          hint: context.tr('journeys.plan.toHint'),
          controller: to,
          validator: validate.destination(() => from.text),
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.done,
        ),
        PlaceChips(
          label: context.tr('journeys.plan.recent'),
          places: _places(past, false),
          onPick: (String p) => to.text = p,
        ),
        Gap(18.fx),
        DepartureField(
          label: context.tr('journeys.plan.departureLabel'),
          hint: context.tr('journeys.plan.departureHint'),
          initialValue: departsAt,
          validator: validate.departure(kept: keptDeparture),
          onChanged: onDeparture,
        ),
      ],
    );
  }
}
