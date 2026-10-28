import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/platform/launch_handoff.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/entrance_scope.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/authentication/logic/states/startup_state.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_branding.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_logo.dart';
import 'package:safe_ride/features/authentication/presentation/widgets/splash_status_slot.dart';

/// The first screen: the brand, while [StartupCubit] decides where the app
/// opens — onboarding, welcome or home.
///
/// It leaves at the later of two moments: the intro ending
/// (`AppDurations.splashIntro`) and the decision being ready. A fast start is
/// not padded with a fixed wait, and a slow one shows a spinner only once the
/// intro is over. A failed decision offers a retry instead of guessing.
///
/// The intro starts from the Android system splash's own image, once the
/// system splash has handed over (`LaunchHandoff`), and turns it into the
/// brand (`SplashLogo`); under reduced motion the brand is simply
/// there and the splash leaves as soon as the decision is.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StartupCubit>(
      create: (_) => sl<StartupCubit>()..decide(),
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> {
  /// The intro holds frame 0 until the system splash has gone.
  final Future<void> _handoff = LaunchHandoff.wait();

  bool _introFinished = false;

  /// Set the moment navigation starts, so the listener and the end of the
  /// intro can never both navigate.
  bool _left = false;

  /// Keys each failure view, so a failure after a retry is a new live region
  /// that a screen reader announces again — never the old one kept in place.
  int _attempt = 0;

  void _retry() {
    setState(() => _attempt++);
    context.read<StartupCubit>().decide(retry: true);
  }

  void _onIntroFinished() {
    if (!mounted) return;
    setState(() => _introFinished = true);
    // The decision may have landed first — on a first launch it is made before
    // the listener even subscribes — so read it rather than wait for a change.
    _leaveIfReady(context.read<StartupCubit>().state);
  }

  void _leaveIfReady(StartupState state) {
    if (_left || !mounted || !_introFinished) return;
    if (state is! StartupReady) return;
    _left = true;
    // `go`, not `push`: the splash must not be reachable by going back.
    context.goNamed(switch (state.destination) {
      StartupDestination.onboarding => AppRoutes.onboarding,
      StartupDestination.welcome => AppRoutes.welcome,
      StartupDestination.home => AppRoutes.home,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          // Scrolls only when the failure copy meets a small screen or a
          // large text scale.
          child: SingleChildScrollView(
            // ⚠️ Unclipped during the intro: frame 0 paints the logo at the
            // window's centre, outside this shrink-wrapped column.
            clipBehavior: _introFinished ? Clip.hardEdge : Clip.none,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenSide),
            child: EntranceScope(
              duration: AppDurations.splashIntro,
              onComplete: _onIntroFinished,
              startWhen: _handoff,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SplashLogo(),
                  Gap(24.fx),
                  SplashBranding(
                    title: context.tr('splash.title'),
                    tagline: context.tr('splash.tagline'),
                  ),
                  Gap(28.fx),
                  BlocConsumer<StartupCubit, StartupState>(
                    listener: (_, StartupState state) => _leaveIfReady(state),
                    builder: (BuildContext context, StartupState state) =>
                        SplashStatusSlot(
                          state: state,
                          introFinished: _introFinished,
                          attempt: _attempt,
                          onRetry: _retry,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
