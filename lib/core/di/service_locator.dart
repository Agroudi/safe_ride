import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/data/repository/local_auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/local_journey_repository.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/plan_journey_cubit.dart';
import 'package:safe_ride/features/safety/data/repository/local_trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_form_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one wiring point — the documented exception to "a feature never
/// imports another feature's internals" (CLAUDE.md §2).
final GetIt sl = GetIt.instance;

/// Called once in `main`, before `runApp`.
///
/// Storage clients and repositories are lazy singletons; screen cubits are
/// factories (one per screen). `PreferencesCubit` is the exception: app-wide
/// state, so a singleton provided above `MaterialApp`; `AppNotifier` is the
/// app's one notification channel, drawn by `NotificationHost`.
Future<void> setupServiceLocator() async {
  // Awaited here so every preference read after this point is synchronous.
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  sl
    ..registerSingleton<AppPreferences>(AppPreferences(prefs))
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    )
    // Swap these for a Firebase / API implementation. One local object is
    // both the auth seam and the read-only session every other feature sees.
    ..registerLazySingleton<LocalAuthRepository>(
      () => LocalAuthRepository(sl<FlutterSecureStorage>()),
    )
    ..registerLazySingleton<AuthRepository>(sl.get<LocalAuthRepository>)
    ..registerLazySingleton<SessionReader>(sl.get<LocalAuthRepository>)
    ..registerLazySingleton<JourneyRepository>(
      () => LocalJourneyRepository(
        sl<FlutterSecureStorage>(),
        sl<SessionReader>(),
      ),
    )
    ..registerLazySingleton<AppNotifier>(AppNotifier.new)
    ..registerLazySingleton<PreferencesCubit>(
      () => PreferencesCubit(sl<AppPreferences>()),
    )
    ..registerFactory<StartupCubit>(
      () => StartupCubit(sl<AppPreferences>(), sl<AuthRepository>()),
    )
    ..registerLazySingleton<TrustedContactsRepository>(
      () => LocalTrustedContactsRepository(
        sl<FlutterSecureStorage>(),
        sl<SessionReader>(),
      ),
    )
    ..registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()))
    ..registerFactory<AccountCubit>(() => AccountCubit(sl<AuthRepository>()))
    ..registerFactory<JourneysCubit>(
      () => JourneysCubit(sl<JourneyRepository>(), sl<SessionReader>()),
    )
    ..registerFactory<PlanJourneyCubit>(
      () => PlanJourneyCubit(sl<JourneyRepository>()),
    )
    ..registerFactory<JourneyCubit>(() => JourneyCubit(sl<JourneyRepository>()))
    ..registerFactory<ContactsCubit>(
      () => ContactsCubit(sl<TrustedContactsRepository>()),
    )
    ..registerFactory<ContactFormCubit>(
      () => ContactFormCubit(sl<TrustedContactsRepository>()),
    );
}
