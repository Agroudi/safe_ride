import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_locales.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/shared_widgets/preference_option.dart';
import 'package:safe_ride/core/shared_widgets/preferences_section.dart';

/// The language and appearance choices, applied the moment they are tapped
/// — nothing is staged. easy_localization saves the language and
/// [PreferencesCubit] the theme. One widget for the preferences sheet and the
/// settings screen, so the two can never offer different choices.
class PreferencesChoices extends StatelessWidget {
  const PreferencesChoices({super.key});

  /// Arabic first, as the app is designed. Each is named in its own script, so
  /// it can be found from a language the reader does not know.
  static const List<Locale> _locales = <Locale>[
    AppLocales.arabic,
    AppLocales.english,
  ];

  static const List<(ThemeMode, IconData)> _modes = <(ThemeMode, IconData)>[
    (ThemeMode.light, Icons.light_mode_rounded),
    (ThemeMode.dark, Icons.dark_mode_rounded),
    (ThemeMode.system, Icons.brightness_auto_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // Both reads are dependencies: the checks move the moment a choice lands.
    final String language = context.locale.languageCode;
    final ThemeMode theme = context.select(
      (PreferencesCubit cubit) => cubit.state.themeMode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PreferencesSection(
          label: context.tr('preferences.language'),
          options: <Widget>[
            for (final Locale locale in _locales)
              PreferenceOption(
                label: context.tr(
                  'preferences.languages.${locale.languageCode}',
                ),
                selected: locale.languageCode == language,
                onTap: () => context.setLocale(locale),
              ),
          ],
        ),
        Gap(24.fx),
        PreferencesSection(
          label: context.tr('preferences.theme'),
          options: <Widget>[
            for (final (ThemeMode mode, IconData icon) in _modes)
              PreferenceOption(
                icon: icon,
                label: context.tr('preferences.themes.${mode.name}'),
                subtitle: mode == ThemeMode.system
                    ? context.tr('preferences.systemHint')
                    : null,
                selected: mode == theme,
                onTap: () =>
                    context.read<PreferencesCubit>().setThemeMode(mode),
              ),
          ],
        ),
      ],
    );
  }
}
