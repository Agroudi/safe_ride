import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/preference_option.dart';
import 'package:safe_ride/core/shared_widgets/preferences_section.dart';

/// Asks which country the user is in now; the chosen code, or null when the
/// sheet was closed. Used by the emergency numbers and by Profile.
Future<String?> showCountryPicker(BuildContext context, {String? selected}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => CountryPickerSheet(selected: selected),
    );

/// Every supported country — its flag, its name in this language and in the
/// other — one tap to choose.
class CountryPickerSheet extends StatelessWidget {
  const CountryPickerSheet({this.selected, super.key});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final String language = context.locale.languageCode;
    final String other = language == 'ar' ? 'en' : 'ar';

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screenSide,
        0,
        AppSpacing.screenSide,
        // ⚠️ `useSafeArea` leaves the bottom inset to us: clear the nav bar.
        24.fx + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PreferencesHeading(
            label: context.tr('country.picker.title'),
            isTitle: true,
          ),
          Gap(8.fx),
          Text(
            context.tr('country.picker.body'),
            style: context.texts.bodySmall?.copyWith(
              color: context.appColors.textMuted,
              height: 1.6,
            ),
          ),
          Gap(18.fx),
          for (final Country c in Countries.sorted(language)) ...<Widget>[
            PreferenceOption(
              label: c.name(language),
              subtitle: c.name(other),
              emoji: c.flag,
              selected: c.code == selected,
              onTap: () => Navigator.of(context).pop(c.code),
            ),
            Gap(10.fx),
          ],
        ],
      ),
    );
  }
}
