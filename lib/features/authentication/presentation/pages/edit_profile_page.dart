import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/authentication/data/models/auth_failure.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/account_state.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_notices.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/profile_fields.dart';

/// Edit the two profile fields there are: full name and the optional (never
/// verified) phone. The email is shown but cannot change — it is the
/// account's key on this phone. Saving pops back to Profile, which reloads
/// from the repository's change stream.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AccountCubit>(
    create: (_) => sl<AccountCubit>()..load(),
    child: const _EditProfileView(),
  );
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  AutovalidateMode _mode = AutovalidateMode.disabled;
  bool _filled = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _saving = true);
    final AuthFailureCode? failure = await context
        .read<AccountCubit>()
        .updateProfile(fullName: _name.text, phone: _phone.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      sl<AppNotifier>().show(AuthNotices.failure(context, failure));
      return;
    }
    sl<AppNotifier>().show(
      AppNotification.success(title: context.tr('profile.notices.updated')),
    );
    context.pop();
  }

  void _onState(BuildContext context, AccountState state) {
    switch (state) {
      case AccountReady(:final user) when !_filled:
        _filled = true;
        _name.text = user.fullName;
        _phone.text = user.phone ?? '';
      case AccountSignedOut():
        context.goNamed(AppRoutes.welcome);
      case AccountFailed(:final code):
        sl<AppNotifier>().show(AuthNotices.failure(context, code));
        context.pop();
      case AccountLoading() || AccountReady():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      listener: _onState,
      builder: (BuildContext context, AccountState state) => FormScaffold(
        formKey: _form,
        autovalidateMode: _mode,
        children: <Widget>[
          TitleBar(title: context.tr('profile.editPage.title')),
          Gap(24.fx),
          if (state case AccountReady(:final user)) ...<Widget>[
            ProfileFields(
              name: _name,
              phone: _phone,
              email: user.email,
              enabled: !_saving,
              onSubmit: _save,
            ),
            Gap(28.fx),
            AppPrimaryButton(
              label: context.tr('profile.editPage.save'),
              busy: _saving,
              onPressed: _save,
            ),
          ] else
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
