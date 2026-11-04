import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/logic/cubit/password_reset_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/password_reset_state.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_notices.dart';

/// "Forgot your password?": Firebase emails a reset link, in the app's
/// language. The answer never says whether the email has an account — the
/// same words either way — so the screen cannot be used to find out.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({this.email = '', super.key});

  /// What the login screen's email field held.
  final String email;

  @override
  Widget build(BuildContext context) => BlocProvider<PasswordResetCubit>(
    create: (_) => sl<PasswordResetCubit>(),
    child: _ForgotPasswordView(email: email),
  );
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView({required this.email});

  final String email;

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.email,
  );
  AutovalidateMode _mode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    context.read<PasswordResetCubit>().send(
      email: _email.text,
      languageCode: context.locale.languageCode,
    );
  }

  void _onState(BuildContext context, PasswordResetState state) {
    if (state case PasswordResetFailed(:final AuthFailureCode code)) {
      sl<AppNotifier>().show(AuthNotices.failure(context, code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PasswordResetCubit, PasswordResetState>(
      listener: _onState,
      builder: (BuildContext context, PasswordResetState state) {
        final bool sending = state is PasswordResetSending;
        final bool sent = state is PasswordResetSent;
        return FormScaffold(
          formKey: _form,
          autovalidateMode: _mode,
          children: <Widget>[
            TitleBar(title: context.tr('auth.reset.title')),
            Gap(16.fx),
            Text(
              context.tr('auth.reset.subtitle'),
              style: context.texts.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
                height: 1.6,
              ),
            ),
            Gap(24.fx),
            AppTextField(
              label: context.tr('auth.login.emailLabel'),
              hint: context.tr('auth.login.emailHint'),
              controller: _email,
              validator: Validators.of(context).email,
              enabled: !sending && !sent,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
              autofillHints: const <String>[AutofillHints.email],
            ),
            Gap(24.fx),
            if (sent) ...<Widget>[
              InfoNote(text: context.tr('auth.reset.sent')),
              Gap(24.fx),
              AppPrimaryButton(
                label: context.tr('auth.reset.back'),
                outlined: true,
                onPressed: () => context.pop(),
              ),
            ] else
              AppPrimaryButton(
                label: context.tr('auth.reset.send'),
                busy: sending,
                onPressed: _send,
              ),
          ],
        );
      },
    );
  }
}
