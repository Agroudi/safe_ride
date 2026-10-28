import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/entrance_item.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/core/shared_widgets/preferences_sheet.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/welcome_hero.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/welcome_top_bar.dart';

/// The signed-out front door: create an account or log in, and change the
/// language or theme before doing either.
///
/// Reached with `go` from the splash and from onboarding, so there is no way
/// back into onboarding from here. Both actions `push`, so back returns here.
///
/// Every arrival plays one staged entrance (`AppDurations.entrance`): the
/// hero, then Create account, then Log in and the preferences pill. Every
/// control takes taps from the first frame, and coming back from a pushed
/// screen never replays it.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // ⚠️ Fills the screen when the content fits and scrolls when it does
        // not — a small phone or a large text size must never overflow. The
        // hero takes the slack between the top bar and the actions.
        child: CustomScrollView(
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screenSide,
                  12.fx,
                  AppSpacing.screenSide,
                  24.fx,
                ),
                child: EntranceScope(
                  duration: AppDurations.entrance,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      EntranceItem.beat(
                        4,
                        rise: AppMotion.riseSmall,
                        child: WelcomeTopBar(
                          label: context.tr('welcome.preferences'),
                          // The page's context, not the pill's — see
                          // `showPreferencesSheet`.
                          onPressed: () => showPreferencesSheet(context),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.fx),
                            child: WelcomeHero(
                              title: context.tr('welcome.title'),
                              subtitle: context.tr('welcome.subtitle'),
                            ),
                          ),
                        ),
                      ),
                      EntranceItem.beat(
                        3,
                        rise: AppMotion.rise,
                        child: AppPrimaryButton(
                          label: context.tr('welcome.createAccount'),
                          onPressed: () =>
                              context.pushNamed(AppRoutes.register),
                        ),
                      ),
                      Gap(12.fx),
                      EntranceItem.beat(
                        4,
                        rise: AppMotion.rise,
                        child: AppPrimaryButton(
                          outlined: true,
                          label: context.tr('welcome.login'),
                          onPressed: () => context.pushNamed(AppRoutes.login),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
