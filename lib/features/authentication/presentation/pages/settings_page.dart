import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/preferences_choices.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';

/// Language and appearance, opened from Profile — the same
/// `PreferencesChoices` as the welcome sheet. A choice applies the moment it
/// is tapped and is kept across restarts (easy_localization saves the
/// language, `PreferencesCubit` the theme). A new language is also kept with
/// the account, for anything the server will write in it.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AccountCubit>(
    create: (_) => sl<AccountCubit>(),
    child: const _SettingsView(),
  );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            28.fx,
          ),
          children: <Widget>[
            TitleBar(title: context.tr('profile.settings.title')),
            Gap(24.fx),
            PreferencesChoices(
              onLanguageChanged: context.read<AccountCubit>().saveLanguage,
            ),
          ],
        ),
      ),
    );
  }
}
