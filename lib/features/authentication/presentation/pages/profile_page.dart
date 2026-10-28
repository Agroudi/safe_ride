import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/link_tile.dart';
import 'package:safe_ride/core/shared_widgets/preferences_section.dart';
import 'package:safe_ride/features/authentication/data/models/user_model.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/account_state.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/auth_notices.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/settings_account_card.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';

/// The Profile tab: who you are, editing it, links to language & appearance
/// and About, and signing out. Home's avatar opens it too.
///
/// Sign-out asks first, then ends the session **only** — the onboarding flag,
/// language and theme stay — and `go`es to welcome, so back cannot return to
/// a signed-in screen. In the authentication feature because the account is
/// its concern.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AccountCubit>(
    create: (_) => sl<AccountCubit>()..load(),
    child: const _ProfileView(),
  );
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  Future<void> _confirmSignOut(BuildContext context) async {
    final AccountCubit account = context.read<AccountCubit>();
    final bool confirmed = await showAppConfirmDialog(
      context,
      title: context.tr('profile.confirm.title'),
      message: context.tr('profile.confirm.message'),
      confirmLabel: context.tr('profile.confirm.confirm'),
      cancelLabel: context.tr('profile.confirm.cancel'),
      destructive: true,
    );
    if (confirmed) await account.signOut();
  }

  void _onState(BuildContext context, AccountState state) {
    switch (state) {
      case AccountSignedOut():
        sl<AppNotifier>().show(AuthNotices.signedOut(context));
        context.goNamed(AppRoutes.welcome);
      case AccountFailed(:final code):
        sl<AppNotifier>().show(AuthNotices.failure(context, code));
      case AccountLoading() || AccountReady():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      listener: _onState,
      builder: (BuildContext context, AccountState state) {
        final UserModel? user = switch (state) {
          AccountReady(:final UserModel user) => user,
          AccountFailed(:final UserModel? user) => user,
          _ => null,
        };
        final bool signingOut = state is AccountReady && state.signingOut;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screenSide,
                AppSpacing.screenTop,
                AppSpacing.screenSide,
                24.fx,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TitleBar(title: context.tr('profile.title'), back: false),
                  Gap(24.fx),
                  PreferencesHeading(label: context.tr('profile.account')),
                  Gap(8.fx),
                  SettingsAccountCard(
                    name: user?.fullName,
                    email: user?.email,
                    phone: user?.phone,
                    deviceOnlyLabel: context.tr('profile.deviceOnly'),
                    unverifiedLabel: context.tr('profile.phoneUnverified'),
                  ),
                  Gap(12.fx),
                  AppPrimaryButton(
                    label: context.tr('profile.edit'),
                    outlined: true,
                    onPressed: user == null
                        ? null
                        : () => context.pushNamed(AppRoutes.editProfile),
                  ),
                  Gap(24.fx),
                  PreferencesHeading(label: context.tr('profile.more')),
                  Gap(8.fx),
                  LinkTile(
                    icon: Icons.translate_rounded,
                    title: context.tr('profile.settings.title'),
                    body: context.tr('profile.settings.body'),
                    onTap: () => context.pushNamed(AppRoutes.settings),
                  ),
                  Gap(10.fx),
                  LinkTile(
                    icon: Icons.info_outline_rounded,
                    title: context.tr('profile.about.title'),
                    body: context.tr('profile.about.body'),
                    onTap: () => context.pushNamed(AppRoutes.about),
                  ),
                  Gap(32.fx),
                  AppPrimaryButton(
                    label: context.tr('profile.signOut'),
                    outlined: true,
                    color: context.appColors.error,
                    busy: signingOut,
                    onPressed: state is AccountLoading
                        ? null
                        : () => _confirmSignOut(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
