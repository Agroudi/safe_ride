import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_links_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contacts_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_tile.dart';
import 'package:safe_ride/features/safety/presentation/widgets/saved_contact_actions.dart';

/// The numbers the user keeps for themselves, with Add. A contact opens to edit
/// or delete, and has Call and Message below it. Saved numbers and connected
/// accounts are two different things: the person here knows nothing of it.
class SavedContactsSection extends StatelessWidget {
  const SavedContactsSection({super.key});

  @override
  Widget build(BuildContext context) {
    void add() => context.pushNamed(AppRoutes.addContact);
    final Map<String, String>? links = AppFeatures.contactAlerts
        ? context.watch<ContactLinksCubit>().state
        : null;

    return BlocBuilder<ContactsCubit, ContactsState>(
      builder: (BuildContext context, ContactsState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeading(title: context.tr('safety.contacts.heading')),
          Gap(10.fx),
          InfoNote(text: context.tr('safety.contacts.notice')),
          Gap(14.fx),
          switch (state) {
            ContactsLoading() => SizedBox(
              height: 120.fx,
              child: const Center(child: CircularProgressIndicator()),
            ),
            ContactsFailed() => AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: context.tr('safety.contacts.failed.title'),
              body: context.tr('safety.contacts.failed.body'),
              actionLabel: context.tr('safety.contacts.failed.retry'),
              onAction: context.read<ContactsCubit>().load,
            ),
            ContactsReady(:final List<TrustedContactModel> contacts)
                when contacts.isEmpty =>
              AppEmptyState(
                icon: Icons.group_add_rounded,
                title: context.tr('safety.contacts.empty.title'),
                body: context.tr('safety.contacts.empty.body'),
                actionLabel: context.tr('safety.contacts.add'),
                onAction: add,
              ),
            ContactsReady(:final List<TrustedContactModel> contacts) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10.fx,
              children: <Widget>[
                for (final TrustedContactModel c in contacts)
                  ContactTile(
                    key: ValueKey<String>(c.id),
                    name: c.fullName,
                    phone: c.phone,
                    relationship: c.relationship,
                    alerts: links == null
                        ? null
                        : context.tr(
                            links[c.id] ==
                                    FirestoreTrustedContactsRepository.digitsOf(
                                      c.phone,
                                    )
                                ? 'safety.contacts.alertsOn'
                                : 'safety.contacts.alertsOff',
                          ),
                    onTap: () => context.pushNamed(
                      AppRoutes.editContact,
                      pathParameters: <String, String>{'id': c.id},
                    ),
                    actions: SavedContactActions(contact: c),
                  ),
                Gap(10.fx),
                AppPrimaryButton(
                  label: context.tr('safety.contacts.add'),
                  onPressed: add,
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}
