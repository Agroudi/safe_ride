import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/preferences_choices.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';

/// Language and appearance, opened from Profile — the same
/// `PreferencesChoices` as the welcome sheet. A choice applies the moment it
/// is tapped and is kept across restarts (easy_localization saves the
/// language, `PreferencesCubit` the theme).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            const PreferencesChoices(),
          ],
        ),
      ),
    );
  }
}
