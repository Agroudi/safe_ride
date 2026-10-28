import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/constants/app_motion.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_footer.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_slide.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/onboarding_top_bar.dart';

/// Three swipeable steps, then the welcome screen — once, for good.
///
/// The steps are **data**, not three pages: change the copy in the translation
/// files and the icons in [_steps], and add or remove a step by editing the
/// list — the indicator and the last-step button follow it.
///
/// The first step plays the screen's entrance; every later motion is a pure
/// function of the page position, so a swipe, a Next tap and back look alike.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const List<OnboardingStep> _steps = <OnboardingStep>[
    OnboardingStep(
      key: 'one',
      icon: Icons.shield_rounded,
      accents: <IconData>[Icons.directions_car_rounded, Icons.route_rounded],
    ),
    OnboardingStep(
      key: 'two',
      icon: Icons.groups_rounded,
      accents: <IconData>[Icons.share_rounded, Icons.schedule_rounded],
    ),
    OnboardingStep(
      key: 'three',
      icon: Icons.health_and_safety_rounded,
      accents: <IconData>[Icons.favorite_rounded, Icons.check_circle_rounded],
    ),
  ];

  final PageController _pages = PageController();
  int _index = 0;

  /// Set from the first Skip / Get started until the screen is gone: a second
  /// tap while the flag is being written would navigate twice.
  bool _leaving = false;

  bool get _isLast => _index == _steps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Writes the flag **before** leaving, so a restart never shows onboarding
  /// again; `go`, so back never does either.
  Future<void> _finish() async {
    if (_leaving) return;
    // Through setState: the step-1 seal is off before the go, so it never
    // flies from the round badge into welcome's square tile.
    setState(() => _leaving = true);
    try {
      await context.read<PreferencesCubit>().completeOnboarding();
    } on Object {
      // A failed write costs one more onboarding on the next launch. Keeping
      // the user here, with buttons that no longer answer, would cost more.
    }
    if (mounted) context.goNamed(AppRoutes.welcome);
  }

  /// Ignored while the slides are still moving: [_index] flips as soon as a
  /// slide is halfway in, so a quick second tap would read "get started" and
  /// finish onboarding — for good — before the last step was ever seen.
  void _next() {
    if (_pages.hasClients && _pages.position.isScrollingNotifier.value) return;
    if (_isLast) {
      _finish();
    } else {
      _show(_index + 1);
    }
  }

  /// Slides to [page] — or cuts to it when the system asks for less motion.
  void _show(int page) {
    if (MediaQuery.disableAnimationsOf(context)) return _pages.jumpToPage(page);
    _pages.animateToPage(
      page,
      duration: AppDurations.medium,
      curve: AppCurves.move,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back steps through the slides before it leaves them. On the first step
    // the pop goes through, to the dispatcher's "press again to exit".
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && _index > 0) _show(_index - 1);
      },
      child: Scaffold(
        body: EntranceScope(
          duration: AppDurations.entrance,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                OnboardingTopBar(onSkip: _finish, showSkip: !_isLast),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _steps.length,
                    onPageChanged: (int index) =>
                        setState(() => _index = index),
                    itemBuilder: (_, int index) => OnboardingSlide(
                      step: _steps[index],
                      pages: _pages,
                      index: index,
                      enter: index == 0,
                      seal: index == 0 && !_leaving,
                    ),
                  ),
                ),
                OnboardingFooter(
                  pages: _pages,
                  count: _steps.length,
                  index: _index,
                  isLast: _isLast,
                  onAction: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
