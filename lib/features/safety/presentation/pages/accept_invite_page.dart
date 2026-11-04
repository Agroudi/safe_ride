import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_invite_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contact_invite_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// Entering the code someone gave you, to become their trusted contact: from
/// then on, an unanswered safety check of theirs can reach this phone.
class AcceptInvitePage extends StatelessWidget {
  const AcceptInvitePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<ContactInviteCubit>(
    create: (_) => sl<ContactInviteCubit>(),
    child: const _AcceptInviteView(),
  );
}

class _AcceptInviteView extends StatefulWidget {
  const _AcceptInviteView();

  @override
  State<_AcceptInviteView> createState() => _AcceptInviteViewState();
}

class _AcceptInviteViewState extends State<_AcceptInviteView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_form.currentState!.validate()) {
      context.read<ContactInviteCubit>().accept(_code.text);
    }
  }

  void _onState(BuildContext context, ContactInviteState state) {
    switch (state) {
      case InviteAccepted(:final String ownerName):
        sl<AppNotifier>().show(
          AppNotification.success(
            title: context.tr(
              'safety.invite.accepted',
              namedArgs: <String, String>{'name': ownerName},
            ),
          ),
        );
        context.pop();
      case InviteFailed(:final code):
        sl<AppNotifier>().show(SafetyNotices.invite(context, code));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ContactInviteCubit, ContactInviteState>(
        listener: _onState,
        builder: (BuildContext context, ContactInviteState state) {
          final bool busy = state is InviteBusy;
          return FormScaffold(
            formKey: _form,
            autovalidateMode: AutovalidateMode.disabled,
            children: <Widget>[
              TitleBar(title: context.tr('safety.invite.acceptTitle')),
              Gap(16.fx),
              InfoNote(text: context.tr('safety.invite.acceptNote')),
              Gap(20.fx),
              AppTextField(
                label: context.tr('safety.invite.codeLabel'),
                controller: _code,
                enabled: !busy,
                validator: Validators.of(context).required,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              Gap(24.fx),
              AppPrimaryButton(
                label: context.tr('safety.invite.accept'),
                busy: busy,
                onPressed: _submit,
              ),
            ],
          );
        },
      );
}
