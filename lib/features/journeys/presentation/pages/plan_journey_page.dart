import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/departure_field.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_form.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';

/// Start a Journey: where from, where to and when (`JourneyForm`). Nothing
/// is saved here; Review journey moves on to the review screen with them.
class PlanJourneyPage extends StatelessWidget {
  const PlanJourneyPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<JourneysCubit>(
    create: (_) => sl<JourneysCubit>()..load(),
    child: const _PlanJourneyView(),
  );
}

class _PlanJourneyView extends StatefulWidget {
  const _PlanJourneyView();

  @override
  State<_PlanJourneyView> createState() => _PlanJourneyViewState();
}

class _PlanJourneyViewState extends State<_PlanJourneyView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  AutovalidateMode _mode = AutovalidateMode.disabled;

  /// Local time; a plan starts at the next quarter-hour.
  DateTime _departsAt = nextQuarterHour(DateTime.now());

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _review() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    context.pushNamed(
      AppRoutes.reviewJourney,
      extra: JourneyDraft(
        origin: _from.text,
        destination: _to.text,
        departsAt: _departsAt.toUtc(),
      ).toExtra(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JourneysState state = context.watch<JourneysCubit>().state;
    final List<JourneyModel> past = state is JourneysReady
        ? state.journeys
        : const <JourneyModel>[];

    return FormScaffold(
      formKey: _form,
      autovalidateMode: _mode,
      children: <Widget>[
        TitleBar(title: context.tr('journeys.plan.title')),
        Gap(24.fx),
        JourneyForm(
          from: _from,
          to: _to,
          departsAt: _departsAt,
          onDeparture: (DateTime d) => _departsAt = d,
          past: past,
        ),
        Gap(24.fx),
        InfoNote(text: context.tr('journeys.notTracked')),
        Gap(24.fx),
        AppPrimaryButton(
          label: context.tr('journeys.plan.review'),
          onPressed: _review,
        ),
      ],
    );
  }
}
