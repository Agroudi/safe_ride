import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_invite_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_links_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contact_invite_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// On an existing contact: whether alerts can reach them, and — until they
/// can — a one-time code for them to enter in their own SafeRide. A number
/// alone reaches nobody: the app cannot send an SMS.
class ContactAlertsCard extends StatelessWidget {
  const ContactAlertsCard({
    required this.contactId,
    required this.phone,
    super.key,
  });

  final String contactId;
  final String phone;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<ContactLinksCubit>(
        create: (_) => sl<ContactLinksCubit>()..load(),
      ),
      BlocProvider<ContactInviteCubit>(create: (_) => sl<ContactInviteCubit>()),
    ],
    child: BlocBuilder<ContactLinksCubit, Map<String, String>>(
      builder: (BuildContext context, Map<String, String> links) {
        final String digits = FirestoreTrustedContactsRepository.digitsOf(
          phone,
        );
        if (links[contactId] == digits) {
          return InfoNote(text: context.tr('safety.invite.linked'));
        }
        return BlocConsumer<ContactInviteCubit, ContactInviteState>(
          listener: (BuildContext context, ContactInviteState state) {
            if (state is InviteFailed) {
              sl<AppNotifier>().show(SafetyNotices.invite(context, state.code));
            }
          },
          builder: (BuildContext context, ContactInviteState state) =>
              state is InviteCreated
              ? _Code(state: state)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    InfoNote(text: context.tr('safety.invite.notLinked')),
                    Gap(10.fx),
                    AppPrimaryButton(
                      label: context.tr('safety.invite.create'),
                      outlined: true,
                      busy: state is InviteBusy,
                      onPressed: () =>
                          context.read<ContactInviteCubit>().create(contactId),
                    ),
                  ],
                ),
        );
      },
    ),
  );
}

class _Code extends StatelessWidget {
  const _Code({required this.state});

  final InviteCreated state;

  @override
  Widget build(BuildContext context) {
    final String code = state.invite.code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: context.texts.headlineSmall?.copyWith(
              color: context.appColors.text,
              letterSpacing: 2,
            ),
          ),
        ),
        Gap(8.fx),
        InfoNote(
          text: context.tr(
            'safety.invite.codeNote',
            namedArgs: <String, String>{
              'date': LocaleNumbers.dateTime(
                context.locale.languageCode,
              ).format(state.invite.expiresAt.toLocal()),
            },
          ),
        ),
        Gap(10.fx),
        AppPrimaryButton(
          label: context.tr('safety.invite.copy'),
          outlined: true,
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
        ),
      ],
    );
  }
}
