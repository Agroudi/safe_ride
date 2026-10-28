import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/states/startup_state.dart';

/// Decides where the app opens: onboarding the first time, then home with a
/// stored session or welcome without one.
///
/// No `BuildContext` and no navigation — the splash listens and navigates.
/// Retrying is calling [decide] again, with `retry: true`.
class StartupCubit extends Cubit<StartupState> {
  StartupCubit(this._preferences, this._auth) : super(const StartupLoading());

  final AppPreferences _preferences;
  final AuthRepository _auth;

  /// A [retry] stays loading for at least
  /// [AppDurations.startupRetryMinimum], so a check that fails again at once
  /// still shows that it ran. The first launch is never padded.
  Future<void> decide({bool retry = false}) async {
    emit(const StartupLoading());

    // First launch: nothing to look up — the auth store is not even touched.
    if (!_preferences.onboardingCompleted) {
      emit(const StartupReady(StartupDestination.onboarding));
      return;
    }

    final Future<void> shown = retry
        ? Future<void>.delayed(AppDurations.startupRetryMinimum)
        : Future<void>.value();

    bool? signedIn;
    try {
      // The timeout is what guarantees the splash never spins forever on a
      // keystore that does not answer.
      signedIn = await _auth.hasSession().timeout(AppDurations.startupTimeout);
    } on Object {
      signedIn = null; // Failed or timed out.
    }
    await shown;
    if (isClosed) return;
    emit(switch (signedIn) {
      true => const StartupReady(StartupDestination.home),
      false => const StartupReady(StartupDestination.welcome),
      null => const StartupFailed(),
    });
  }
}
