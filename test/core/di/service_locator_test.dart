import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/country/country_repository.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_monitor.dart';
import 'package:safe_ride/features/journeys/data/repository/incident_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_tracker.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_repository.dart';
import 'package:safe_ride/features/journeys/data/repository/safety_check_service.dart';
import 'package:safe_ride/features/journeys/data/repository/location_source.dart';
import 'package:safe_ride/features/journeys/logic/cubit/incident_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/safety_check_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/tracking_cubit.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/repository/phone_dialer.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/emergency_state.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_ride/core/safety/emergency_position.dart';
import 'package:safe_ride/features/journeys/data/repository/tracker_position_reader.dart';
import 'package:safe_ride/features/safety/data/repository/call_launcher.dart';
import 'package:safe_ride/features/safety/logic/cubit/emergency_location_cubit.dart';
import 'package:safe_ride/features/safety/data/repository/message_composer.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_reach_cubit.dart';
import 'package:safe_ride/features/assistant/data/repository/assistant_repository.dart';
import 'package:safe_ride/features/assistant/data/repository/conversation_store.dart';
import 'package:safe_ride/features/assistant/data/repository/mock_assistant_repository.dart';
import 'package:safe_ride/features/assistant/logic/cubit/assistant_cubit.dart';

import '../../features/assistant/assistant_fakes.dart';
import '../../features/journeys/tracking_fakes.dart';
import '../../features/safety/invite_fakes.dart';

class _Messaging extends Fake implements FirebaseMessaging {}

/// The app's real wiring — one Firebase auth object as the session every
/// feature reads, the Firestore repositories — over `firebase_auth_mocks`
/// and `fake_cloud_firestore`, with two accounts on one phone: each sees only
/// its own journeys and contacts, by list and by id, and signing out or in
/// touches neither the other account nor the device's preferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseAuth firebaseAuth;
  late FakeLocation location;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'ar'});
    firebaseAuth = MockFirebaseAuth();
    await sl.reset();
    await setupServiceLocator(
      auth: firebaseAuth,
      firestore: FakeFirebaseFirestore(),
      messaging: _Messaging(),
      location: location = FakeLocation(),
      trackStore: MemoryTrackStore(),
      incidents: MemoryIncidentRepository(),
      safetyChecks: MemorySafetyCheckRepository(),
      safetyNotifications: FakeSafetyNotifications(),
      invites: FakeInvites(),
      geocoding: FakeGeocoding(),
      routing: FakeRouting(),
      mapTiles: FakeMapTiles(),
      conversations: MemoryConversationStore(),
    );
  });
  tearDown(sl.reset);

  test('the auth repository is the session every feature reads', () {
    expect(identical(sl<AuthRepository>(), sl<SessionReader>()), isTrue);
  });

  test('emergency numbers come from the phone: country and dataset', () async {
    expect(identical(sl<CountryRepository>(), sl<CountryRepository>()), isTrue);
    final EmergencyCubit cubit = sl<EmergencyCubit>();
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state, const EmergencyNeedsCountry());
    await sl<CountryRepository>().choose('QA');
    await pumpEventQueue();
    expect(cubit.state, isA<EmergencyReady>());
    expect(sl<PhoneDialer>(), isA<UrlLauncherPhoneDialer>());
  });

  test('one call launcher for every Call and Message; where the user is comes '
      'from the one recording', () {
    expect(identical(sl<CallLauncher>(), sl<CallLauncher>()), isTrue);
    expect(sl<MessageComposer>(), isA<UrlLauncherMessageComposer>());
    final ContactReachCubit reach = sl<ContactReachCubit>();
    addTearDown(reach.close);
    expect(identical(reach, sl<ContactReachCubit>()), isFalse);
    expect(sl<EmergencyPositionReader>(), isA<TrackerPositionReader>());
    final EmergencyLocationCubit a = sl<EmergencyLocationCubit>();
    final EmergencyLocationCubit b = sl<EmergencyLocationCubit>();
    addTearDown(a.close);
    addTearDown(b.close);
    expect(identical(a, b), isFalse);
  });

  test('SafeRide AI: the local mock until a backend exists, the phone store, '
      'a cubit per screen', () {
    expect(sl<AssistantRepository>(), isA<MockAssistantRepository>());
    expect(sl<ConversationStore>(), isA<MemoryConversationStore>());
    final AssistantCubit a = sl<AssistantCubit>();
    final AssistantCubit b = sl<AssistantCubit>();
    addTearDown(a.close);
    addTearDown(b.close);
    expect(identical(a, b), isFalse);
  });

  test('one safety-check service; a cubit per prompt', () {
    expect(
      identical(sl<SafetyCheckService>(), sl<SafetyCheckService>()),
      isTrue,
    );
    expect(sl<SafetyCheckRepository>(), isA<MemorySafetyCheckRepository>());
    expect(identical(sl<SafetyCheckCubit>(), sl<SafetyCheckCubit>()), isFalse);
  });

  test('one incident monitor, fed by the one tracker', () {
    expect(identical(sl<IncidentMonitor>(), sl<IncidentMonitor>()), isTrue);
    expect(sl<IncidentRepository>(), isA<MemoryIncidentRepository>());
    expect(identical(sl<IncidentCubit>(), sl<IncidentCubit>()), isFalse);
  });

  test('one route tracker for the app, over the given location', () async {
    expect(identical(sl<JourneyTracker>(), sl<JourneyTracker>()), isTrue);
    expect(identical(sl<LocationSource>(), location), isTrue);
    expect(identical(sl<TrackingCubit>(), sl<TrackingCubit>()), isFalse);
    // Nobody signed in: nothing to resume, nothing asked.
    await sl<JourneyTracker>().recover();
    expect(sl<JourneyTracker>().journeyId, isNull);
    expect(location.asked, 0);
  });

  test('two accounts on one phone never see each other\'s data', () async {
    final AuthRepository auth = sl<AuthRepository>();
    final JourneyRepository journeys = sl<JourneyRepository>();
    final TrustedContactsRepository contacts = sl<TrustedContactsRepository>();
    final AppPreferences prefs = sl<AppPreferences>();
    await prefs.setOnboardingCompleted();
    await prefs.setThemeMode(ThemeMode.dark);

    await auth.register(
      fullName: 'Layla Hassan',
      email: 'layla@example.com',
      password: 'Secret123',
      languageCode: 'ar',
    );
    final JourneyModel trip = await journeys.plan(
      origin: 'Olaya Street',
      destination: 'Airport',
      departsAt: DateTime.now().add(const Duration(hours: 2)),
    );
    final TrustedContactModel sister = await contacts.add(
      fullName: 'Mona Saleh',
      phone: '+966 55 111 2222',
    );
    final String laylaUid = (await sl<SessionReader>().signedInUser())!.id;
    await auth.logout();

    await auth.register(
      fullName: 'Omar Test',
      email: 'omar@example.com',
      password: 'Another9X',
      languageCode: 'en',
    );
    expect(await journeys.journeys(), isEmpty);
    expect(await contacts.contacts(), isEmpty);
    expect(await journeys.journey(trip.id), isNull);
    expect(await contacts.contact(sister.id), isNull);
    await expectLater(
      journeys.cancel(trip.id),
      throwsA(
        isA<JourneyFailure>().having(
          (JourneyFailure f) => f.code,
          'code',
          JourneyFailureCode.notFound,
        ),
      ),
    );
    // Omar's own number may match Layla's contact: lists are per account.
    await contacts.add(fullName: 'Mona', phone: '+966551112222');
    await auth.logout();

    // The mock signs in whoever was registered last; Firebase signs in the
    // account the email names.
    firebaseAuth.mockUser = MockUser(uid: laylaUid, email: 'layla@example.com');
    await auth.login(email: 'Layla@Example.com ', password: 'Secret123');
    expect((await journeys.journeys()).single.status, JourneyStatus.planned);
    expect((await contacts.contacts()).single.fullName, 'Mona Saleh');
    expect((await auth.currentUser())?.fullName, 'Layla Hassan');

    expect(prefs.onboardingCompleted, isTrue);
    expect(prefs.themeMode, ThemeMode.dark);
    final SharedPreferences store = await SharedPreferences.getInstance();
    expect(store.getString('locale'), 'ar');
  });

  test('signed out, no feature can read or write anyone\'s data', () async {
    final AuthRepository auth = sl<AuthRepository>();
    await auth.register(
      fullName: 'Layla Hassan',
      email: 'layla@example.com',
      password: 'Secret123',
      languageCode: 'ar',
    );
    await sl<TrustedContactsRepository>().add(
      fullName: 'Mona Saleh',
      phone: '+966551112222',
    );
    await auth.logout();

    expect(await sl<SessionReader>().signedInUser(), isNull);
    await expectLater(
      sl<JourneyRepository>().journeys(),
      throwsA(
        isA<JourneyFailure>().having(
          (JourneyFailure f) => f.code,
          'code',
          JourneyFailureCode.signedOut,
        ),
      ),
    );
    await expectLater(
      sl<TrustedContactsRepository>().contacts(),
      throwsA(
        isA<ContactFailure>().having(
          (ContactFailure f) => f.code,
          'code',
          ContactFailureCode.signedOut,
        ),
      ),
    );
  });
}
