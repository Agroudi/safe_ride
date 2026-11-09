import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/features/safety/data/models/contact_reach.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_reach_cubit.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_reach_buttons.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// Call and Message under a saved number on the Trusted Contacts list. The
/// messaging app opens empty: this is everyday use, and the user writes what
/// they want. Reads [ContactReachCubit] from above.
class SavedContactActions extends StatelessWidget {
  const SavedContactActions({required this.contact, super.key});

  final TrustedContactModel contact;

  Future<void> _call(BuildContext context) async {
    final DialOutcome? outcome = await context.read<ContactReachCubit>().call(
      contact.id,
      contact.phone,
    );
    if (context.mounted) {
      SafetyNotices.showDial(context, outcome, contact.fullName);
    }
  }

  Future<void> _message(BuildContext context) async {
    final ComposeOutcome? outcome = await context
        .read<ContactReachCubit>()
        .message(contact.id, contact.phone, '');
    if (context.mounted) {
      SafetyNotices.showCompose(context, outcome, contact.fullName);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ContactReachCubit, String?>(
    builder: (BuildContext context, String? opening) => ContactReachButtons(
      name: contact.fullName,
      reach: ContactReach.of(contact.phone),
      busy: opening != null,
      onCall: () => _call(context),
      onMessage: () => _message(context),
    ),
  );
}
