import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contacts_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_tile.dart';

/// The account's trusted contacts, alphabetical, with Add. A contact opens
/// to edit or delete. The screen says plainly that SafeRide neither verifies
/// numbers nor contacts anyone.
class TrustedContactsPage extends StatelessWidget {
  const TrustedContactsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<ContactsCubit>(
    create: (_) => sl<ContactsCubit>()..load(),
    child: const _TrustedContactsView(),
  );
}

class _TrustedContactsView extends StatelessWidget {
  const _TrustedContactsView();

  @override
  Widget build(BuildContext context) {
    void add() => context.pushNamed(AppRoutes.addContact);

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<ContactsCubit, ContactsState>(
          builder: (BuildContext context, ContactsState state) => ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screenSide,
              AppSpacing.screenTop,
              AppSpacing.screenSide,
              28.fx,
            ),
            children: <Widget>[
              TitleBar(title: context.tr('safety.contacts.title')),
              Gap(16.fx),
              InfoNote(text: context.tr('safety.contacts.notice')),
              Gap(20.fx),
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
                ContactsReady(:final List<TrustedContactModel> contacts) =>
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10.fx,
                    children: <Widget>[
                      for (final TrustedContactModel c in contacts)
                        ContactTile(
                          key: ValueKey<String>(c.id),
                          name: c.fullName,
                          phone: c.phone,
                          relationship: c.relationship,
                          onTap: () => context.pushNamed(
                            AppRoutes.editContact,
                            pathParameters: <String, String>{'id': c.id},
                          ),
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
        ),
      ),
    );
  }
}
