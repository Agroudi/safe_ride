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

  /// `extra`: the email typed on the login screen, if any.
  static const String forgotPassword = 'forgot-password';
  static const String forgotPasswordPath = '/forgot-password';

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

  /// The pre-journey checklist that starts a planned journey; path
  /// parameter `id`.
  static const String startJourney = 'start-journey';
  static const String startJourneyPath = '/journey/start/:id';

  /// Choosing a place on the map. `extra`: which one, and any already chosen.
  static const String pickPlace = 'pick-place';
  static const String pickPlacePath = '/plan/place';

  /// A journey on the map. Path parameter `id`.
  static const String journeyMap = 'journey-map';
  static const String journeyMapPath = '/journey/map/:id';

  /// Sharing the current location: start it, or manage the share that is on.
  static const String shareLocation = 'share-location';
  static const String shareLocationPath = '/sharing';

  /// Sharing a journey in progress. Path parameter `id`.
  static const String shareJourney = 'share-journey';
  static const String shareJourneyPath = '/sharing/journey/:id';

  /// What a share's link opens, with no account. The token is the link's `#`
  /// part, so it never reaches a server log or a Referer. The path matches the
  /// web viewer's and the Android intent filter's.
  static const String sharedView = 'shared-view';
  static const String sharedViewPath = '/s';

  // Safety screens, pushed over the tabs.

  static const String trustedContacts = 'trusted-contacts';
  static const String trustedContactsPath = '/safety/contacts';

  static const String addContact = 'add-contact';
  static const String addContactPath = '/safety/contacts/new';

  /// Path parameter `id`.
  static const String editContact = 'edit-contact';
  static const String editContactPath = '/safety/contacts/edit/:id';

  /// One connection; path parameter `id`, the other account's.
  static const String manageConnection = 'manage-connection';
  static const String manageConnectionPath = '/safety/connection/view/:id';

  /// Answering an invite. The token is the link's `#` part, as with a share,
  /// and none means the person pastes it. The path matches the web page's and
  /// the Android intent filter's.
  static const String connectionInvite = 'connection-invite';
  static const String connectionInvitePath = '/c';

  /// Where to find help: after a safety check nobody answered, or any time.
  static const String safetyHelp = 'safety-help';
  static const String safetyHelpPath = '/safety/help';

  static const String safetyGuide = 'safety-guide';
  static const String safetyGuidePath = '/safety/guide';

  static const String journeySafety = 'journey-safety';
  static const String journeySafetyPath = '/safety/journeys';

  static const String emergencyInfo = 'emergency-info';
  static const String emergencyInfoPath = '/safety/emergency';

  /// Alerts received as someone's trusted contact.
  static const String safetyAlerts = 'safetyAlerts';
  static const String safetyAlertsPath = '/safety/alerts';

  /// Entering an invite code to become someone's trusted contact.
  static const String acceptInvite = 'accept-invite';
  static const String acceptInvitePath = '/safety/invite';

  // Profile screens, pushed over the tabs.

  static const String editProfile = 'edit-profile';
  static const String editProfilePath = '/profile/edit';

  static const String deleteAccount = 'delete-account';
  static const String deleteAccountPath = '/profile/delete';

  /// Language and appearance.
  static const String settings = 'settings';
  static const String settingsPath = '/profile/settings';

  static const String about = 'about';
  static const String aboutPath = '/profile/about';
}
