import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/safety_help_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/safety_help_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_reach_buttons.dart';
import 'package:safe_ride/features/safety/presentation/widgets/help_person.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// The people the user can reach themselves. Connected people by name only —
/// a connection shares no number — with what SafeRide cannot do for them;
/// saved numbers with Call and Message, which only open the phone or
/// messaging app. Numbers are not drawn: only those apps show them.
class HelpPeopleSection extends StatelessWidget {
  const HelpPeopleSection({super.key});

  Future<void> _call(BuildContext context, HelpSavedContact contact) async {
    final DialOutcome? outcome = await context.read<SafetyHelpCubit>().call(
      contact.id,
    );
    if (context.mounted) {
      SafetyNotices.showDial(context, outcome, contact.name);
    }
  }

  Future<void> _message(BuildContext context, HelpSavedContact contact) async {
    final ComposeOutcome? outcome = await context
        .read<SafetyHelpCubit>()
        .message(contact.id, context.tr('safety.reach.body'));
    if (context.mounted) {
      SafetyNotices.showCompose(context, outcome, contact.name);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SafetyHelpCubit, SafetyHelpState>(
        builder: (BuildContext context, SafetyHelpState state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final bool nobody =
              state.connected.isEmpty &&
              state.saved.isEmpty &&
              !state.connectionsFailed &&
              !state.savedFailed;
          final bool reachable = state.saved.any(
            (HelpSavedContact c) => c.reach == ContactReach.available,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10.fx,
            children: <Widget>[
              if (nobody) InfoNote(text: context.tr('safety.help.people.none')),
              if (state.connected.isNotEmpty) ...<Widget>[
                for (final HelpConnection c in state.connected)
                  HelpPerson(name: c.name),
                InfoNote(text: context.tr('safety.help.people.cannotAlert')),
              ],
              if (state.connectionsFailed)
                InfoNote(text: context.tr('safety.help.people.failed')),
              for (final HelpSavedContact c in state.saved)
                HelpPerson(
                  name: c.name,
                  detail: c.relationship,
                  actions: ContactReachButtons(
                    name: c.name,
                    reach: c.reach,
                    busy: state.reaching != null,
                    onCall: () => _call(context, c),
                    onMessage: () => _message(context, c),
                  ),
                ),
              if (reachable)
                InfoNote(text: context.tr('safety.help.people.messageNote')),
              if (state.savedFailed)
                InfoNote(text: context.tr('safety.help.people.failed')),
              AppPrimaryButton(
                label: context.tr('safety.help.people.manage'),
                outlined: true,
                onPressed: () => context.pushNamed(AppRoutes.trustedContacts),
              ),
            ],
          );
        },
      );
}
