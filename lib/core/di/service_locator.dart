import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:safe_ride/core/account/account_data.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/country/country_cubit.dart';
import 'package:safe_ride/core/country/country_repository.dart';
import 'package:safe_ride/core/firebase/firestore_account_data.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/preferences/preferences_account_data.dart';
import 'package:safe_ride/core/preferences/preferences_cubit.dart';
import 'package:safe_ride/core/push/push_notifications.dart';
import 'package:safe_ride/core/push/push_permission_cubit.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/authentication/data/repository/firebase_auth_repository.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/account_deletion_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/auth_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/password_reset_cubit.dart';
import 'package:safe_ride/features/authentication/logic/cubit/startup_cubit.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/escalation_sync.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_account_data.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/file_track_store.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_escalation_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/firestore_route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/geolocator_location_source.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_monitor.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/local_safety_notifications.dart';
import 'package:safe_ride/features/journeys/data/repository/location_source.dart';
import 'package:safe_ride/features/journeys/data/repository/route_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_notifications.dart';
import 'package:safe_ride/features/journeys/data/repository/track_store.dart';
import 'package:safe_ride/features/journeys/logic/cubit/escalation_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journey_start_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/journeys_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/incident_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/plan_journey_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_check_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_notice_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/tracking_cubit.dart';
import 'package:safe_ride/features/safety/data/repository/cloud_contact_invite_repository.dart';
import 'package:safe_ride/features/safety/data/repository/contact_invite_repository.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_data_source.dart';
import 'package:safe_ride/features/safety/data/repository/emergency_repository.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_received_alerts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/data/repository/received_alerts_repository.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_form_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_invite_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_links_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/received_alerts_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one wiring point — the documented exception to "a feature never
/// imports another feature's internals" (CLAUDE.md §2).
final GetIt sl = GetIt.instance;

/// Called once in `main`, after `Firebase.initializeApp`, before `runApp`.
///
/// Storage clients and repositories are lazy singletons; screen cubits are
/// factories (one per screen). `PreferencesCubit` is the exception: app-wide
/// state, so a singleton provided above `MaterialApp`; `AppNotifier` is the
/// app's one notification channel, drawn by `NotificationHost`.
///
/// The Firebase clients default to the app's own, the location to the
/// phone's and the route files to the app's directory; tests pass fakes.
/// `JourneyTracker` is the one service that outlives screens: it records
/// the journey in progress.
Future<void> setupServiceLocator({
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  FirebaseMessaging? messaging,
  LocationSource? location,
  TrackStore? trackStore,
  IncidentRepository? incidents,
  SafetyCheckRepository? safetyChecks,
  SafetyNotifications? safetyNotifications,
  ContactInviteRepository? invites,
  PhoneDialer? dialer,
}) async {
  // Awaited here so every preference read after this point is synchronous.
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  sl
    ..registerSingleton<AppPreferences>(AppPreferences(prefs))
    ..registerLazySingleton<FirebaseAuth>(() => auth ?? FirebaseAuth.instance)
    ..registerLazySingleton<FirebaseFirestore>(
      () => firestore ?? FirebaseFirestore.instance,
    )
    ..registerLazySingleton<FirebaseMessaging>(
      () => messaging ?? FirebaseMessaging.instance,
    )
    // One Firebase object is both the auth seam and the read-only session
    // every other feature sees.
    ..registerLazySingleton<FirebaseAuthRepository>(
      () => FirebaseAuthRepository(
        sl<FirebaseAuth>(),
        sl<FirebaseFirestore>(),
        // In this order: nothing may write for the account once it is erased.
        accountData: () => <AccountData>[
          sl<PushNotifications>(),
          JourneyAccountData(
            tracker: sl<JourneyTracker>(),
            safetyChecks: sl<SafetyCheckService>(),
            store: sl<TrackStore>(),
            incidents: sl<IncidentRepository>(),
            checks: sl<SafetyCheckRepository>(),
          ),
          FirestoreAccountData(sl<FirebaseFirestore>()),
          PreferencesAccountData(sl<AppPreferences>()),
        ],
      ),
    )
    ..registerLazySingleton<AuthRepository>(sl.get<FirebaseAuthRepository>)
    ..registerLazySingleton<SessionReader>(sl.get<FirebaseAuthRepository>)
    ..registerLazySingleton<JourneyRepository>(
      () => FirestoreJourneyRepository(
        sl<FirebaseFirestore>(),
        sl<SessionReader>(),
      ),
    )
    ..registerLazySingleton<LocationSource>(
      () => location ?? GeolocatorLocationSource(sl<FirebaseMessaging>()),
    )
    ..registerLazySingleton<TrackStore>(() => trackStore ?? FileTrackStore())
    ..registerLazySingleton<RouteRepository>(
      () => FirestoreRouteRepository(
        sl<FirebaseFirestore>(),
        sl<SessionReader>(),
      ),
    )
    ..registerLazySingleton<IncidentRepository>(
      () => incidents ?? FileIncidentRepository(),
    )
    ..registerLazySingleton<IncidentMonitor>(
      () => IncidentMonitor(sl<IncidentRepository>()),
    )
    ..registerLazySingleton<SafetyCheckRepository>(
      () => safetyChecks ?? FileSafetyCheckRepository(),
    )
    ..registerLazySingleton<SafetyNotifications>(
      () => safetyNotifications ?? LocalSafetyNotifications(),
    )
    ..registerLazySingleton<SafetyCheckService>(
      () => SafetyCheckService(
        incidents: sl<IncidentRepository>(),
        checks: sl<SafetyCheckRepository>(),
        journeys: sl<JourneyRepository>(),
        session: sl<SessionReader>(),
        notifications: sl<SafetyNotifications>(),
        inForeground: () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      ),
    )
    ..registerLazySingleton<EscalationRepository>(
      () => FirestoreEscalationRepository(sl<FirebaseFirestore>()),
    )
    ..registerLazySingleton<EscalationSync>(
      () => EscalationSync(
        checks: sl<SafetyCheckRepository>(),
        incidents: sl<IncidentRepository>(),
        repository: sl<EscalationRepository>(),
        session: sl<SessionReader>(),
        updates: sl<SafetyCheckService>().changes,
        live: AppFeatures.contactAlerts,
      ),
    )
    ..registerFactory<SafetyCheckCubit>(
      () => SafetyCheckCubit(sl<SafetyCheckService>(), sl<EscalationSync>()),
    )
    ..registerFactory<EscalationCubit>(
      () => EscalationCubit(
        sl<SafetyCheckRepository>(),
        sl<EscalationRepository>(),
        sl<EscalationSync>(),
        sl<SessionReader>(),
      ),
    )
    ..registerFactory<SafetyNoticeCubit>(
      () => SafetyNoticeCubit(sl<SafetyNotifications>()),
    )
    ..registerLazySingleton<JourneyTracker>(
      () => JourneyTracker(
        location: sl<LocationSource>(),
        store: sl<TrackStore>(),
        route: sl<RouteRepository>(),
        journeys: sl<JourneyRepository>(),
        session: sl<SessionReader>(),
        observer: sl<IncidentMonitor>(),
      ),
    )
    ..registerLazySingleton<CountryRepository>(
      () => ProfileCountryRepository(
        sl<AppPreferences>(),
        sl<FirebaseFirestore>(),
        sl<SessionReader>(),
      ),
    )
    ..registerFactory<CountryCubit>(() => CountryCubit(sl<CountryRepository>()))
    ..registerLazySingleton<AppNotifier>(AppNotifier.new)
    ..registerLazySingleton<PreferencesCubit>(
      () => PreferencesCubit(sl<AppPreferences>()),
    )
    ..registerFactory<StartupCubit>(
      () => StartupCubit(sl<AppPreferences>(), sl<AuthRepository>()),
    )
    ..registerLazySingleton<TrustedContactsRepository>(
      () => FirestoreTrustedContactsRepository(
        sl<FirebaseFirestore>(),
        sl<SessionReader>(),
      ),
    )
    ..registerLazySingleton<PushNotifications>(
      () => PushNotifications(
        messaging: sl<FirebaseMessaging>(),
        db: sl<FirebaseFirestore>(),
        session: sl<SessionReader>(),
        notifier: sl<AppNotifier>(),
        installId: sl<AppPreferences>().installId,
      ),
    )
    ..registerLazySingleton<DeviceRegistration>(sl.get<PushNotifications>)
    ..registerFactory<PushPermissionCubit>(
      () => PushPermissionCubit(sl<PushNotifications>()),
    )
    ..registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()))
    ..registerFactory<PasswordResetCubit>(
      () => PasswordResetCubit(sl<AuthRepository>()),
    )
    ..registerFactory<AccountCubit>(
      () => AccountCubit(sl<AuthRepository>(), sl<DeviceRegistration>()),
    )
    ..registerFactory<AccountDeletionCubit>(
      () => AccountDeletionCubit(sl<AuthRepository>()),
    )
    ..registerFactory<JourneysCubit>(
      () => JourneysCubit(
        sl<JourneyRepository>(),
        sl<SessionReader>(),
        tracker: sl<JourneyTracker>(),
      ),
    )
    ..registerFactory<PlanJourneyCubit>(
      () => PlanJourneyCubit(sl<JourneyRepository>()),
    )
    ..registerFactory<JourneyCubit>(() => JourneyCubit(sl<JourneyRepository>()))
    ..registerFactory<JourneyStartCubit>(
      () => JourneyStartCubit(sl<JourneyRepository>()),
    )
    ..registerFactory<TrackingCubit>(() => TrackingCubit(sl<JourneyTracker>()))
    ..registerFactory<IncidentCubit>(
      () => IncidentCubit(sl<IncidentRepository>(), sl<SessionReader>()),
    )
    ..registerFactory<ContactsCubit>(
      () => ContactsCubit(sl<TrustedContactsRepository>()),
    )
    ..registerFactory<ContactFormCubit>(
      () => ContactFormCubit(sl<TrustedContactsRepository>()),
    )
    ..registerLazySingleton<ContactInviteRepository>(
      () =>
          invites ??
          CloudContactInviteRepository(
            // The functions run beside the database, in Dammam.
            FirebaseFunctions.instanceFor(region: 'me-central2'),
            sl<FirebaseFirestore>(),
            sl<SessionReader>(),
          ),
    )
    ..registerFactory<ContactLinksCubit>(
      () => ContactLinksCubit(sl<ContactInviteRepository>()),
    )
    ..registerFactory<ContactInviteCubit>(
      () => ContactInviteCubit(sl<ContactInviteRepository>()),
    )
    ..registerLazySingleton<ReceivedAlertsRepository>(
      () => FirestoreReceivedAlertsRepository(
        sl<FirebaseFirestore>(),
        sl<SessionReader>(),
      ),
    )
    ..registerFactory<ReceivedAlertsCubit>(
      () => ReceivedAlertsCubit(
        sl<ReceivedAlertsRepository>(),
        sl<PhoneDialer>(),
      ),
    )
    ..registerLazySingleton<EmergencyRepository>(
      () => BundledEmergencyRepository(EmergencyDataSource()),
    )
    ..registerLazySingleton<PhoneDialer>(
      () => dialer ?? const UrlLauncherPhoneDialer(),
    )
    ..registerFactory<EmergencyCubit>(
      () => EmergencyCubit(
        sl<CountryRepository>(),
        sl<EmergencyRepository>(),
        sl<PhoneDialer>(),
      ),
    );
}
