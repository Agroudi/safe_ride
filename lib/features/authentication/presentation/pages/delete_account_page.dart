import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_deletion_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/account_deletion_state.dart';

/// Deleting the account: what goes, the password (Firebase requires a recent
/// sign-in, and it stops a borrowed phone), one last question. On success
/// it `go`es to welcome, so back cannot return to a deleted account.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AccountDeletionCubit>(
    create: (_) => sl<AccountDeletionCubit>(),
    child: const _DeleteAccountView(),
  );
}

class _DeleteAccountView extends StatefulWidget {
  const _DeleteAccountView();

  @override
  State<_DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<_DeleteAccountView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  AutovalidateMode _mode = AutovalidateMode.disabled;
  String? _passwordError;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _passwordError = null);
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    final AccountDeletionCubit cubit = context.read<AccountDeletionCubit>();
    final bool yes = await showAppConfirmDialog(
      context,
      title: context.tr('profile.delete.confirm.title'),
      message: context.tr('profile.delete.confirm.message'),
      confirmLabel: context.tr('profile.delete.confirm.confirm'),
      cancelLabel: context.tr('profile.delete.confirm.cancel'),
      destructive: true,
    );
    if (!yes || !mounted) return;
    // Read now: Profile leaves for welcome the moment the session ends.
    final String done = context.tr('profile.delete.done');
    final GoRouter router = GoRouter.of(context);
    if (await cubit.delete(_password.text)) {
      sl<AppNotifier>().show(AppNotification.success(title: done));
      router.goNamed(AppRoutes.welcome);
    }
  }

  void _onState(BuildContext context, AccountDeletionState state) {
    switch (state) {
      case DeletionFailed(code: AuthFailureCode.invalidCredentials):
        setState(
          () => _passwordError = context.tr('profile.delete.wrongPassword'),
        );
      case DeletionFailed():
        sl<AppNotifier>().show(
          AppNotification.error(
            title: context.tr('profile.delete.failed.title'),
            message: context.tr('profile.delete.failed.body'),
          ),
        );
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<AccountDeletionCubit, AccountDeletionState>(
        listener: _onState,
        builder: (BuildContext context, AccountDeletionState state) {
          final bool busy = state is DeletionBusy || state is DeletionDone;
          return FormScaffold(
            formKey: _form,
            autovalidateMode: _mode,
            children: <Widget>[
              TitleBar(title: context.tr('profile.delete.title')),
              Gap(20.fx),
              Text(
                context.tr('profile.delete.intro'),
                style: context.texts.bodyMedium?.copyWith(
                  color: context.appColors.text,
                  height: 1.6,
                ),
              ),
              Gap(14.fx),
              InfoNote(text: context.tr('profile.delete.note')),
              Gap(20.fx),
              AppTextField(
                label: context.tr('profile.delete.password'),
                controller: _password,
                obscurable: true,
                enabled: !busy,
                errorText: _passwordError,
                validator: Validators.of(context).required,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
              ),
              Gap(24.fx),
              AppPrimaryButton(
                label: context.tr('profile.delete.submit'),
                color: context.appColors.error,
                busy: busy,
                onPressed: _submit,
              ),
            ],
          );
        },
      );
}
