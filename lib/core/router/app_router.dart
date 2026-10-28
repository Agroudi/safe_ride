import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/router/app_tab_shell.dart';
import 'package:safe_ride/features/authentication/presentation/pages/about_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/edit_profile_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/login_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/onboarding_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/profile_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/register_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/settings_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/splash_page.dart';
import 'package:safe_ride/features/authentication/presentation/pages/welcome_page.dart';
import 'package:safe_ride/features/journeys/data/models/journey_draft.dart';
import 'package:safe_ride/features/journeys/presentation/pages/edit_journey_page.dart';
import 'package:safe_ride/features/journeys/presentation/pages/home_page.dart';
import 'package:safe_ride/features/journeys/presentation/pages/journey_page.dart';
import 'package:safe_ride/features/journeys/presentation/pages/my_journeys_page.dart';
import 'package:safe_ride/features/journeys/presentation/pages/plan_journey_page.dart';
import 'package:safe_ride/features/journeys/presentation/pages/review_journey_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/contact_form_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/emergency_info_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/journey_safety_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/safety_center_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/safety_guide_page.dart';
import 'package:safe_ride/features/safety/presentation/pages/trusted_contacts_page.dart';

/// Central navigation.
///
/// **`go` vs `push`:** `push` stacks a screen the user can step back from;
/// `go` *replaces* the stack. Use `go` when stepping back would be wrong —
/// leaving the splash, finishing onboarding, signing in or out — and `push`
/// for everything else (welcome pushes login and register, home pushes the
/// planning screens). `AppBackButtonDispatcher` covers the screens `go`
/// leaves with nothing to pop.
///
/// **Signed in** is a `StatefulShellRoute`: Home, My Journeys, Safety and
/// Profile,
/// each with its own stack, drawn by `AppTabShell`. Planning a journey and a
/// journey's details are top-level routes, so they open over the tab bar.
///
/// **Pages:** every route uses `pageBuilder:` with `AppPages` — `stage` for
/// the `go` targets and the tab roots, `task` for the pushes — never
/// `builder:`. One page type for every route, or a covered page's exit
/// silently never plays (see `AppPages`).
abstract final class AppRouter {
  /// The app's one router.
  static final GoRouter router = create();

  /// A fresh router over the app's routes — the app's, or a test's opened on
  /// [initialLocation].
  static GoRouter create({String initialLocation = AppRoutes.splashPath}) =>
      GoRouter(initialLocation: initialLocation, routes: _routes());

  static List<RouteBase> _routes() => <RouteBase>[
    _stage(AppRoutes.splash, AppRoutes.splashPath, const SplashPage()),
    _stage(
      AppRoutes.onboarding,
      AppRoutes.onboardingPath,
      const OnboardingPage(),
    ),
    _stage(AppRoutes.welcome, AppRoutes.welcomePath, const WelcomePage()),
    _task(AppRoutes.login, AppRoutes.loginPath, const LoginPage()),
    _task(AppRoutes.register, AppRoutes.registerPath, const RegisterPage()),
    StatefulShellRoute(
      pageBuilder: (BuildContext context, GoRouterState state, Widget shell) =>
          AppPages.stage(context, state, shell),
      navigatorContainerBuilder:
          (
            BuildContext context,
            StatefulNavigationShell shell,
            List<Widget> children,
          ) => AppTabShell(shell: shell, children: children),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            _stage(AppRoutes.home, AppRoutes.homePath, const HomePage()),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            _stage(
              AppRoutes.myJourneys,
              AppRoutes.myJourneysPath,
              const MyJourneysPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            _stage(
              AppRoutes.safety,
              AppRoutes.safetyPath,
              const SafetyCenterPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            _stage(
              AppRoutes.profile,
              AppRoutes.profilePath,
              const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    _task(
      AppRoutes.planJourney,
      AppRoutes.planJourneyPath,
      const PlanJourneyPage(),
    ),
    GoRoute(
      path: AppRoutes.reviewJourneyPath,
      name: AppRoutes.reviewJourney,
      // Reached only from the plan screen; a restored or hand-typed
      // location without its places goes back to planning.
      redirect: (BuildContext context, GoRouterState state) =>
          JourneyDraft.from(state.extra) == null
          ? state.namedLocation(AppRoutes.planJourney)
          : null,
      pageBuilder: (BuildContext context, GoRouterState state) => AppPages.task(
        context,
        state,
        ReviewJourneyPage(draft: JourneyDraft.from(state.extra)!),
      ),
    ),
    GoRoute(
      path: AppRoutes.journeyPath,
      name: AppRoutes.journey,
      pageBuilder: (BuildContext context, GoRouterState state) => AppPages.task(
        context,
        state,
        JourneyPage(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.editJourneyPath,
      name: AppRoutes.editJourney,
      pageBuilder: (BuildContext context, GoRouterState state) => AppPages.task(
        context,
        state,
        EditJourneyPage(id: state.pathParameters['id']!),
      ),
    ),
    _task(
      AppRoutes.trustedContacts,
      AppRoutes.trustedContactsPath,
      const TrustedContactsPage(),
    ),
    _task(
      AppRoutes.addContact,
      AppRoutes.addContactPath,
      const ContactFormPage(),
    ),
    GoRoute(
      path: AppRoutes.editContactPath,
      name: AppRoutes.editContact,
      pageBuilder: (BuildContext context, GoRouterState state) => AppPages.task(
        context,
        state,
        ContactFormPage(id: state.pathParameters['id']),
      ),
    ),
    _task(
      AppRoutes.safetyGuide,
      AppRoutes.safetyGuidePath,
      const SafetyGuidePage(),
    ),
    _task(
      AppRoutes.journeySafety,
      AppRoutes.journeySafetyPath,
      const JourneySafetyPage(),
    ),
    _task(
      AppRoutes.emergencyInfo,
      AppRoutes.emergencyInfoPath,
      const EmergencyInfoPage(),
    ),
    _task(
      AppRoutes.editProfile,
      AppRoutes.editProfilePath,
      const EditProfilePage(),
    ),
    _task(AppRoutes.settings, AppRoutes.settingsPath, const SettingsPage()),
    _task(AppRoutes.about, AppRoutes.aboutPath, const AboutPage()),
  ];

  static GoRoute _stage(String name, String path, Widget page) => GoRoute(
    path: path,
    name: name,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppPages.stage(context, state, page),
  );

  static GoRoute _task(String name, String path, Widget page) => GoRoute(
    path: path,
    name: name,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        AppPages.task(context, state, page),
  );
}
