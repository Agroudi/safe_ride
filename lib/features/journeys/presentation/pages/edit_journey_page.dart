import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/states/journey_state.dart';
import 'package:safe_ride/features/journeys/logic/states/journeys_state.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_form.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/journey_notices.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';

/// Edit a **planned** journey's places and departure — the plan screen's
/// `JourneyForm`, filled in. Save changes stores them and goes back to the
/// details, which reload. A closed or missing journey cannot be edited, and
/// the screen says so.
class EditJourneyPage extends StatelessWidget {
  const EditJourneyPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<JourneyCubit>(create: (_) => sl<JourneyCubit>()..load(id)),
      BlocProvider<JourneysCubit>(create: (_) => sl<JourneysCubit>()..load()),
    ],
    child: const _EditJourneyView(),
  );
}

class _EditJourneyView extends StatefulWidget {
  const _EditJourneyView();

  @override
  State<_EditJourneyView> createState() => _EditJourneyViewState();
}

class _EditJourneyViewState extends State<_EditJourneyView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  AutovalidateMode _mode = AutovalidateMode.disabled;
  DateTime? _departsAt;
  DateTime? _stored;
  bool _filled = false;
  bool _saving = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, JourneyState state) {
    if (state is JourneyReady && !_filled) {
      // Once: later reloads must not overwrite what is being typed.
      _filled = true;
      setState(() {
        _from.text = state.journey.origin;
        _to.text = state.journey.destination;
        _departsAt = _stored = state.journey.departsAt?.toLocal();
      });
    } else if (state is JourneyReady && !state.busy && _saving) {
      _saving = false;
      sl<AppNotifier>().show(JourneyNotices.updated(context));
      context.pop();
    } else if (state is JourneyFailed && _saving) {
      _saving = false;
      sl<AppNotifier>().show(JourneyNotices.failure(context, state.code));
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final DateTime? departs = _departsAt;
    if (!_form.currentState!.validate() || departs == null) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    _saving = true;
    context.read<JourneyCubit>().update(
      origin: _from.text,
      destination: _to.text,
      departsAt: departs.toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JourneysState all = context.watch<JourneysCubit>().state;

    return BlocConsumer<JourneyCubit, JourneyState>(
      listener: _onState,
      builder: (BuildContext context, JourneyState state) {
        final JourneyModel? journey = switch (state) {
          JourneyReady(:final JourneyModel journey) => journey,
          JourneyFailed(:final JourneyModel? journey) => journey,
          _ => null,
        };
        final bool editable =
            journey != null && journey.status == JourneyStatus.planned;
        return FormScaffold(
          formKey: _form,
          autovalidateMode: _mode,
          children: <Widget>[
            TitleBar(title: context.tr('journeys.edit.title')),
            Gap(24.fx),
            if (state is JourneyLoading)
              const Center(child: CircularProgressIndicator())
            else if (!editable)
              AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: context.tr(
                  journey == null
                      ? 'journeys.detail.missingTitle'
                      : 'journeys.detail.settled',
                ),
                body: context.tr('journeys.notTracked'),
              )
            else ...<Widget>[
              JourneyForm(
                from: _from,
                to: _to,
                departsAt: _departsAt,
                onDeparture: (DateTime d) => _departsAt = d,
                keptDeparture: _stored,
                past: all is JourneysReady
                    ? all.journeys
                    : const <JourneyModel>[],
              ),
              Gap(28.fx),
              AppPrimaryButton(
                label: context.tr('journeys.edit.save'),
                busy: state is JourneyReady && state.busy,
                onPressed: _save,
              ),
            ],
          ],
        );
      },
    );
  }
}
