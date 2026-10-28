import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/preferences_choices.dart';
import 'package:safe_ride/core/shared_widgets/preferences_section.dart';

/// Opens the language and appearance choices over the current screen. Pass
/// the **page's** context: themes inherited between it and the navigator are
/// frozen into the sheet, while the app theme above the navigator stays live —
/// which is what repaints the open sheet when its own switch is used.
///
/// ⚠️ Known limitation: the scrim's screen-reader label and "tap to close"
/// hint are read once, when the sheet opens, so after a language switch they
/// stay in the old language until the sheet is reopened.
Future<void> showPreferencesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Lets large text grow the sheet past half the screen; then it scrolls.
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => const PreferencesSheet(),
  );
}

/// The preferences sheet: its title, [PreferencesChoices] and Done. The open
/// sheet re-renders in the new direction and palette the moment a choice
/// lands. Opened from welcome; signed in, the settings screen shows the same
/// choices.
class PreferencesSheet extends StatelessWidget {
  const PreferencesSheet({super.key});

  @override
  Widget build(BuildContext context) {
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
            label: context.tr('preferences.title'),
            isTitle: true,
          ),
          Gap(20.fx),
          const PreferencesChoices(),
          Gap(28.fx),
          AppPrimaryButton(
            label: context.tr('preferences.done'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
