import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';

/// The skip action on the trailing edge — left in Arabic, right in English.
///
/// On the last step there is nothing left to skip, so the action fades out
/// but keeps its space: the slide under it must not jump up as it goes. On
/// arrival it fades in on the last beat of the page's entrance, in place.
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({super.key, this.onSkip, this.showSkip = true});

  final VoidCallback? onSkip;
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24.fx, 12.fx, 14.fx, 0),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        // Hidden means hidden to touch and to screen readers too, not only
        // to the eye.
        child: EntranceItem.beat(
          4,
          child: IgnorePointer(
            ignoring: !showSkip,
            child: ExcludeSemantics(
              excluding: !showSkip,
              child: AnimatedOpacity(
                opacity: showSkip ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppDurations.short,
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    context.tr('onboarding.skip'),
                    style: context.texts.labelMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
