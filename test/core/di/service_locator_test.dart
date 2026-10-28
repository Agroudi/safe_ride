import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/preferences/app_preferences.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/authentication/data/repository/auth_repository.dart';
import 'package:safe_ride/features/journeys/data/models/journey_failure.dart';
import 'package:safe_ride/features/journeys/data/models/journey_model.dart';
import 'package:safe_ride/features/journeys/data/repository/journey_repository.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's real wiring — one auth object as the session every feature
/// reads — across two local accounts on one phone: each sees only its own
/// journeys and contacts, by list and by id, and signing out or in touches
/// neither the other account nor the device's preferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'ar'});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await sl.reset();
    await setupServiceLocator();
  });
  tearDown(sl.reset);

  test('the auth repository is the session every feature reads', () {
    expect(identical(sl<AuthRepository>(), sl<SessionReader>()), isTrue);
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
    await auth.logout();

    await auth.register(
      fullName: 'Omar Test',
      email: 'omar@example.com',
      password: 'Another9X',
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
