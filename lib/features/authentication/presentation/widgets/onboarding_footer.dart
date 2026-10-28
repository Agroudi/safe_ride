import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/extensions/locale_numbers.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_dots.dart';

/// The page indicator on the leading edge and the action filling the rest.
/// On the last step the action reads "get started" instead of "next".
///
/// The row rises in on the last beat of the page's entrance; the indicator
/// follows [pages] as they move.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    required this.pages,
    required this.count,
    required this.index,
    required this.isLast,
    super.key,
    this.onAction,
  });

  final PageController pages;
  final int count;
  final int index;
  final bool isLast;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final NumberFormat digits = LocaleNumbers.decimal(
      context.locale.languageCode,
    );

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24.fx, 12.fx, 24.fx, 24.fx),
      child: EntranceItem.beat(
        4,
        rise: AppMotion.riseSmall,
        child: Row(
          children: <Widget>[
            // The dots mean nothing read aloud; "step 2 of 3" says it instead.
            Semantics(
              label: context.tr(
                'onboarding.progress',
                namedArgs: <String, String>{
                  'current': digits.format(index + 1),
                  'total': digits.format(count),
                },
              ),
              excludeSemantics: true,
              child: OnboardingDots(pages: pages, count: count, index: index),
            ),
            Gap(20.fx),
            Expanded(
              child: AppPrimaryButton(
                label: context.tr(
                  isLast ? 'onboarding.start' : 'onboarding.next',
                ),
                onPressed: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
