import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/auth_state.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_notices.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/register_fields.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/register_footer.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';

/// Create a demo account — saved on this phone only, and the page says so.
/// A taken email shows under the email field; what was typed stays. While
/// it runs the form is locked and the button busy, so it cannot submit
/// twice. Success signs in and goes home with a notification.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AuthCubit>(
    create: (_) => sl<AuthCubit>(),
    child: const _RegisterView(),
  );
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  AutovalidateMode _mode = AutovalidateMode.disabled;

  /// The repository's verdict on the email, cleared as soon as it changes.
  String? _emailError;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _fullName,
      _email,
      _phone,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _emailError = null);
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    context.read<AuthCubit>().register(
      fullName: _fullName.text,
      email: _email.text,
      phone: _phone.text,
      password: _password.text,
    );
  }

  void _onState(BuildContext context, AuthState state) {
    switch (state) {
      case AuthSucceeded():
        sl<AppNotifier>().show(AuthNotices.registered(context));
        context.goNamed(AppRoutes.home);
      case AuthFailed(code: AuthFailureCode.emailTaken):
        setState(() => _emailError = context.tr('auth.errors.emailTaken'));
      case AuthFailed(:final AuthFailureCode code):
        sl<AppNotifier>().show(AuthNotices.failure(context, code));
      case AuthInitial() || AuthSubmitting():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: _onState,
      builder: (BuildContext context, AuthState state) {
        // Still busy after success, until the route has changed.
        final bool busy = state is AuthSubmitting || state is AuthSucceeded;
        return FormScaffold(
          formKey: _form,
          autovalidateMode: _mode,
          children: <Widget>[
            TitleBar(title: context.tr('auth.register.title')),
            Gap(24.fx),
            RegisterFields(
              fullName: _fullName,
              email: _email,
              phone: _phone,
              password: _password,
              confirm: _confirm,
              enabled: !busy,
              emailError: _emailError,
              onSubmit: _submit,
              onEmailChanged: () {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            Gap(28.fx),
            AppPrimaryButton(
              label: context.tr('auth.register.submit'),
              busy: busy,
              onPressed: _submit,
            ),
            Gap(16.fx),
            RegisterFooter(
              // Replaces register, so back from login still means welcome.
              onLogin: busy
                  ? null
                  : () => context.pushReplacementNamed(AppRoutes.login),
            ),
          ],
        );
      },
    );
  }
}
