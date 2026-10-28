/// Route names and paths. Navigate by **name** (`context.goNamed(AppRoutes.login)`),
/// never with a raw path string.
abstract final class AppRoutes {
  static const String splash = 'splash';
  static const String splashPath = '/';

  static const String onboarding = 'onboarding';
  static const String onboardingPath = '/onboarding';

  /// The signed-out front door: create an account or log in.
  static const String welcome = 'welcome';
  static const String welcomePath = '/welcome';

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String register = 'register';
  static const String registerPath = '/register';

  // The signed-in tabs (`AppTabShell`): each keeps its own stack.

  /// The journey dashboard — where signing in lands.
  static const String home = 'home';
  static const String homePath = '/home';

  static const String myJourneys = 'my-journeys';
  static const String myJourneysPath = '/journeys';

  /// The Safety Center: contacts, the guide, journey safety, emergencies.
  static const String safety = 'safety';
  static const String safetyPath = '/safety';

  /// Account, language and appearance; sign out.
  static const String profile = 'profile';
  static const String profilePath = '/profile';

  // Pushed over the tabs, so the tab bar steps aside while a journey is planned.

  static const String planJourney = 'plan-journey';
  static const String planJourneyPath = '/plan';

  /// `extra`: `{'origin': …, 'destination': …}` from the plan screen.
  static const String reviewJourney = 'review-journey';
  static const String reviewJourneyPath = '/plan/review';

  /// One journey; path parameter `id`. The literal `view` segment keeps it
  /// from ever swallowing a sibling route (CLAUDE.md §11).
  static const String journey = 'journey';
  static const String journeyPath = '/journey/view/:id';

  /// Edit a planned journey; path parameter `id`.
  static const String editJourney = 'edit-journey';
  static const String editJourneyPath = '/journey/edit/:id';

  // Safety screens, pushed over the tabs.

  static const String trustedContacts = 'trusted-contacts';
  static const String trustedContactsPath = '/safety/contacts';

  static const String addContact = 'add-contact';
  static const String addContactPath = '/safety/contacts/new';

  /// Path parameter `id`.
  static const String editContact = 'edit-contact';
  static const String editContactPath = '/safety/contacts/edit/:id';

  static const String safetyGuide = 'safety-guide';
  static const String safetyGuidePath = '/safety/guide';

  static const String journeySafety = 'journey-safety';
  static const String journeySafetyPath = '/safety/journeys';

  static const String emergencyInfo = 'emergency-info';
  static const String emergencyInfoPath = '/safety/emergency';

  // Profile screens, pushed over the tabs.

  static const String editProfile = 'edit-profile';
  static const String editProfilePath = '/profile/edit';

  /// Language and appearance.
  static const String settings = 'settings';
  static const String settingsPath = '/profile/settings';

  static const String about = 'about';
  static const String aboutPath = '/profile/about';
}
