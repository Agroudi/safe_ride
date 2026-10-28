import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/auth_state.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_header.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_notices.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/login_fields.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/login_footer.dart';

/// Sign in against the demo accounts on this phone. A wrong password shows
/// under its field, an unknown email as a notification offering registration;
/// what was typed stays. While it runs the form is locked and the button
/// busy, so it cannot submit twice.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AuthCubit>(
    create: (_) => sl<AuthCubit>(),
    child: const _LoginView(),
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// Quiet until the first submit, then re-checks as the user types — errors
  /// before anyone has tried are noise.
  AutovalidateMode _mode = AutovalidateMode.disabled;

  /// The repository's verdict on the password, cleared as soon as it changes.
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _passwordError = null);
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    context.read<AuthCubit>().login(
      email: _email.text,
      password: _password.text,
    );
  }

  void _onState(BuildContext context, AuthState state) {
    switch (state) {
      // `go`: signing in replaces the auth stack, so back cannot return here.
      case AuthSucceeded():
        context.goNamed(AppRoutes.home);
      case AuthFailed(code: AuthFailureCode.wrongPassword):
        setState(
          () => _passwordError = context.tr('auth.errors.wrongPassword'),
        );
      case AuthFailed(:final AuthFailureCode code):
        sl<AppNotifier>().show(
          AuthNotices.failure(
            context,
            code,
            // Replaces login, so back from registration still means welcome.
            onCreateAccount: () =>
                context.pushReplacementNamed(AppRoutes.register),
          ),
        );
      case AuthInitial() || AuthSubmitting():
        break;
    }
  }

  void _clearPasswordError() {
    if (_passwordError != null) setState(() => _passwordError = null);
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
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppBackButton(),
            ),
            Gap(20.fx),
            AuthHeader(
              title: context.tr('auth.login.title'),
              subtitle: context.tr('auth.login.subtitle'),
            ),
            Gap(28.fx),
            LoginFields(
              email: _email,
              password: _password,
              enabled: !busy,
              passwordError: _passwordError,
              onSubmit: _submit,
              onPasswordChanged: _clearPasswordError,
            ),
            Gap(28.fx),
            AppPrimaryButton(
              label: context.tr('auth.login.submit'),
              busy: busy,
              onPressed: _submit,
            ),
            Gap(24.fx),
            LoginFooter(
              onForgotPassword: busy
                  ? null
                  : () => sl<AppNotifier>().show(
                      AuthNotices.resetUnavailable(context),
                    ),
              // Replaces login, so back from registration still means welcome.
              onCreateAccount: busy
                  ? null
                  : () => context.pushReplacementNamed(AppRoutes.register),
            ),
          ],
        );
      },
    );
  }
}
