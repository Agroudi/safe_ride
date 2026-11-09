# CLAUDE.md — SafeRide

The single source of truth for this project. Read it before changing code, and
update it when a decision changes.

**SafeRide** is a transportation-safety app (Arabic + English, light + dark),
being built as an MVP in batches from the *SafeRide Flutter MVP master prompt*
(the product spec; it is kept outside the repo). §16 records the decisions and
the batch status. There is no Figma file yet: the palette and screen rules come
from that spec, not from a design board.

The project was started from a Flutter base extracted from **PrepAI** (a
63-screen Arabic-first LMS wired to a FastAPI backend). It keeps that base's
structure, conventions and the lessons it paid for — and nothing of its domain.
There is **no network backend yet**: preferences and the session check are
local (§16), and §9 documents how an API is wired when one exists.

---

## 0. Starting a new project from this base

The base's one-time setup. Status for SafeRide in the last column.

| # | Change | Where | SafeRide |
|---|---|---|---|
| 1 | Package name `basecode` → the project's | `pubspec.yaml` `name:`, then replace `package:basecode/` across `lib/` | done — `safe_ride` |
| 2 | Application id `com.example.basecode` | `android/app/build.gradle.kts` (`namespace`, `applicationId`), iOS bundle id in Xcode | done — `com.saferide.falcon` (Android + iOS, batch 7) |
| 3 | App label | `android:label` in `AndroidManifest.xml`, `app.name` in both translation files | done — SafeRide (also iOS `CFBundleDisplayName`) |
| 4 | Design frame size | `AppDesign.width / height / figmaFrameWidth` — see §7 | unchanged (390×844) until a Figma file exists |
| 5 | Palette | the **values** in `AppColors` (the names are roles, keep them) | done — light + dark from the spec |
| 6 | Font + type scale | `AppTextTheme` | unchanged — Cairo |
| 7 | Logo | `AppLogo` — the one widget that draws it | done — `assets/images/logo_mark.svg` |
| 8 | Onboarding copy + icons | `onboarding.*` keys, `_steps` in `OnboardingPage` | done |
| 9 | Launcher icon + native splash | by hand in `android/app/src/main/res/` (§12), or add `flutter_launcher_icons` / `flutter_native_splash` for it | Android adaptive icon + launch colours done by hand in `res/` (§12); legacy PNG mipmaps and the iOS icon **open** |
| 10 | Unused packages | delete them from `pubspec.yaml` (§6) | done — only what the code imports |

Then build screens after the signed-in tabs (`AppTabShell`).

---

## 1. What is in the project

- **Structure**: feature-first, five layers per feature, a `core/` that every
  feature shares (§2).
- **Screens**: splash (decides where the app opens) → onboarding (3 swipeable
  steps, once) → welcome → login ⇄ register → the signed-in tabs: **Home**
  (journey dashboard), **My Journeys** (status filters, cancel), **Safety**
  (trusted contacts, safety guide, journey safety, emergency numbers),
  **Profile** (edit profile, language & appearance, About, sign-out). From
  Home: plan a journey (places + departure) → review → the journey's
  details (planned / in progress / completed / cancelled; a planned one
  can be edited, and starts only through the pre-journey safety
  checklist; while it is in progress, its route, speed and distance are
  recorded with the user's permission, and a live map shows it). Places can
  be picked on a map, with a route preview (`docs/maps.md`). The user can
  share their location or a journey in progress through a private link that
  needs no account to open (`docs/location-sharing.md`). Two accounts can
  connect through a private invite; a connection shares nothing by itself
  (`docs/connections.md`).
  A safety check nobody answered stays open until the user says "I'm okay"
  or the journey ends, with **Get help**: emergency numbers, sharing and the
  user's people, each their own tap (`docs/escalation.md` §11).
  Emergency information and Get help share one emergency directory — the
  chosen country's checked numbers by what happened, where the user is, and
  what to say on the call; Call opens the phone app and nothing more
  (`docs/emergency.md`). A number the user saved can be called or texted
  from Get help and Trusted Contacts — the phone or messaging app opens and
  the user sends; a connection shares no number (`docs/emergency.md` §10).
  Login offers a password reset. Accounts are **Firebase Authentication**;
  profiles, journeys and contacts are **Cloud Firestore**, per account, with
  the phone's offline copy (§9, §16).
- **Notifications**: one custom toast system for the whole app
  (`core/notifications/`, §16) — success, error, warning, info, offline.
- **Preferences**: language, theme mode (light / dark / system) and the
  onboarding flag survive a restart; the welcome sheet and Profile's
  Language & appearance screen change the first two live (§16).
- **Validation** rules for every field, live after the first submit (§10).
- **Theme**: light and dark palettes as a theme extension, an explicit colour
  scheme, Cairo, and a Figma→Flutter unit converter (§7).
- **Localization**: Arabic (RTL) and English (LTR, fallback), chosen by the
  user or the device, with real CLDR plurals and Arabic-Indic digits (§8).
- **Routing** with `go_router`, named routes, and a back-button dispatcher that
  never lets the app close from the middle of a flow (§11).
- **Backend: Firebase, on the Spark plan** — Auth, Firestore with Security
  Rules (`firestore.rules`), Cloud Messaging's receiving end. Cloud Functions
  in `functions/` are written and emulator-tested, and **stay undeployed**:
  Spark cannot run them, so trusted-contact alerts are off (§16). The designs
  are `docs/firebase-architecture.md` and `docs/escalation.md`; what stands
  between this and a release is `docs/PRODUCTION_READINESS.md`.
- **Clean by rule:** no backups, no commented-out code, no file, key, asset,
  package or member that nothing uses. Delete what a change makes unused in
  the same change.

---

## 2. Architecture

**Feature first.** No domain layer, no entities, no use cases, no data sources,
no mappers, no DTOs, no services — unless explicitly requested.

```
lib/
  core/        # shared by every feature
  features/    # one folder per feature
  main.dart    # bootstrap + App
```

### Feature structure

```
features/<feature>/
  data/
    models/        # freezed + json_serializable
    repository/    # Retrofit service + the repository that wraps it
  logic/
    cubit/
    states/
  presentation/
    pages/         # one screen each
    widgets/       # the pieces those screens are built from
```

Every feature in the base has the **full tree**, so the structure is visible
from day one. `presentation/` holds the real screens; `data/` and `logic/` hold
**named skeleton files** — one comment line saying what goes there, no code:

| File | Becomes |
|---|---|
| `data/models/<x>_model.dart` | the freezed model(s) |
| `data/repository/<feature>_repository.dart` | the Retrofit service + the repository around it |
| `logic/states/<feature>_state.dart` | the `sealed` state classes |
| `logic/cubit/<feature>_cubit.dart` | the cubit |

Fill them following §9 when the feature gets its API. Rename a file if the
feature's model is not the one the name guesses. A new feature gets the same
four files.

A repository that the app must be able to swap is an `abstract interface
class <Feature>Repository` with the implementation beside it —
`AuthRepository` + `FirebaseAuthRepository`, `JourneyRepository` +
`FirestoreJourneyRepository`, `TrustedContactsRepository` +
`FirestoreTrustedContactsRepository`. The service locator chooses the
implementation; nothing else names it. **Firebase types stop at the
repository**: no cubit, state or widget imports `firebase_auth` or
`cloud_firestore`, and every Firebase exception becomes the feature's
failure code there. There is no separate data-source class: the repository
is the adapter (a forwarding layer would be architecture for its own sake).

A feature may hold more than one cubit when it has more than one screen-sized
concern — the authentication feature has `StartupCubit` (the splash's
decision), `AuthCubit` (the forms) and `AccountCubit` (profile and its
edit screen).

What a feature needs to know about **who is signed in** comes from
`core/session/SessionReader`, never from the authentication feature: the
auth repository implements it, and the service locator hands the same
instance out as `AuthRepository` and `SessionReader`. Its `changes` stream
fires on sign-in, sign-out and a profile edit, so Home's greeting follows a
rename at once.

Every local repository exposes a `Stream<void> changes`; a list cubit
listens and reloads, so a change saved on a pushed screen shows on the
screen beneath it with no hand-off.

### Core structure

```
core/
  constants/       # AppDesign, AppSpacing, AppRadius, AppDurations, AppMotion, AppCurves, AppLocales, AppAssets
  country/         # the country the user is in: catalog, repository (phone + profile), cubit
  di/              # service_locator.dart — get_it wiring, the one cross-feature import point
  firebase/        # Firestore paths, the Timestamp converter, the shared live query, `settle`
  notifications/   # AppNotification + AppNotifier + NotificationHost — the toast system
  extensions/      # context, figma units, locale digits
  platform/        # Dart ends of the native glue in MainActivity (LaunchHandoff)
  preferences/     # AppPreferences + PreferencesCubit — app-wide settings
  push/            # PushNotifications (FCM), its permission cubit, the background handler
  router/          # AppRoutes, AppRouter, AppPages, AppTabShell, AppBackButtonDispatcher
  safety/          # EscalationGate (an unanswered check) · EmergencyPositionReader (where the
                   #   user is, for their own eyes) — read by the safety feature
  security/        # BearerToken: the 256-bit token of a share's link and an invite
  session/         # SessionReader + SessionUser — who is signed in, for every feature
  shared_widgets/  # widgets used by 2+ features
  theme/           # AppColors, AppTextTheme, AppTheme, SystemBars
  validation/      # Validators
```

### Feature independence

A feature **never** imports another feature's internals (widgets, cubits,
models, repositories). If two features need the same thing, move it to `core/`.
If both need the same *endpoint*, each gets its own repository with its own
small projection — two classes that call one route are cheaper than a
dependency that couples two features.

`core/di/service_locator.dart` is the exception: it is the wiring point. So
are `core/router/` and `main.dart`, which name every feature's pages.

---

## 3. File map

```
lib/
  main.dart                         # portrait lock, edge-to-edge, EasyLocalization, Firebase, DI, push, App
                                    #   (builder: notifications + the safety-check prompt over every route)
  firebase_options.dart             # generated by `flutterfire configure` — project identifiers, no secrets
  core/
    constants/app_constants.dart    # AppDesign · AppSpacing · AppRadius · AppDurations · AppFeatures
    constants/app_asset_loader.dart # reads the translations (see §8: every EasyLocalization uses it)
    account/account_data.dart       # AccountData: what must go when an account is deleted
    account/sign_out_step.dart      # SignOutStep: what must finish before the session ends
    constants/app_motion.dart       # AppCurves (the five curves) · AppMotion (offsets, distances)
    constants/app_locales.dart
    constants/public_links.dart     # PublicLinks.base: where the public pages live
    constants/app_assets.dart
    di/service_locator.dart         # get_it: prefs, Firebase clients, location, route store (injectable
                                    #   for tests), repositories, JourneyTracker, cubits
    firebase/firestore_paths.dart   # users/{uid}, journeys (+ checklist, route, tracking), contacts, devices
    firebase/firestore_account_data.dart # every path account deletion removes
    firebase/timestamp_converter.dart    # Timestamp ↔ UTC DateTime; a pending server time reads as now
                                         #   (Nullable…: missing or pending stays null — startedAt)
    firebase/user_collection.dart   # one live query per user collection, shared by every screen
    firebase/firestore_write.dart   # settle(): true once the server confirms; false after
                                    #   AppDurations.syncWait (saved here, pending)
    extensions/context_extensions.dart   # context.texts / colors / appColors / isRtl / isDark /
                                         #   reduceMotion / directionSign
    extensions/figma_extensions.dart     # .fx / .fsp
    notifications/app_notification.dart  # kind, title, message, action, duration, id
    notifications/app_notifier.dart      # the one channel: show / dismiss (one at a time)
    notifications/notification_host.dart # draws it over every route (MaterialApp.builder)
    notifications/notification_card.dart · notification_parts.dart   # the card
    extensions/locale_numbers.dart       # Arabic-Indic digits, dates, the pickers' locale
    platform/launch_handoff.dart         # waits for MainActivity to remove the system splash
    preferences/app_preferences.dart     # onboarding flag, theme mode, install id, the chosen country
                                         #   (+ its account and whether it is still to send)
    preferences/preferences_cubit.dart · preferences_state.dart   # app-wide singleton
    preferences/preferences_account_data.dart # the chosen country, on deletion
    push/push_notifications.dart     # FCM: permission, register / onRegistered (the FID), foreground,
                                     #   opened (allowlisted routes), DeviceRegistration for sign-out
    push/push_permission_cubit.dart · push_background.dart
    country/country.dart             # Country (code, names ar/en, flag) + Countries.supported (7)
    country/country_repository.dart  # CountryRepository + ProfileCountryRepository (phone first,
                                     #   then users/{uid}.country; one rule settles a disagreement)
    country/country_cubit.dart       # CountryCubit + CountryState (one per screen)
    safety/escalation_gate.dart      # OpenEscalation (no location), ResolveOutcome, EscalationGate
    safety/emergency_position.dart   # PositionReading (freshness, accuracy), EmergencyPosition,
                                     #   EmergencyPositionReader — reads, never asks, never sends
    security/bearer_token.dart       # generate (Random.secure), isValid
    router/app_routes.dart
    router/app_router.dart
    router/app_pages.dart            # AppPages.stage (go) / .task (push) / .up — the only page type
    router/app_back_dispatcher.dart
    router/app_tab_shell.dart        # the signed-in tabs: one navigator each, fade-through
    session/session_reader.dart      # SessionReader + SessionUser (id, fullName, firstName)
    shared_widgets/app_primary_button.dart   # filled, or `outlined: true`; PressScale + AppButtonLabel
    shared_widgets/app_button_label.dart · press_scale.dart   # label swap, press feedback
    shared_widgets/entrance_scope.dart · entrance_item.dart   # one screen's staged entrance
    shared_widgets/brand_mark.dart       # BrandMarkGeometry + BrandMarkPainter (the mark in Dart)
    shared_widgets/brand_seal.dart · brand_seal_shape.dart   # the one Hero (`brand-seal`) + shuttle
    shared_widgets/app_text_field.dart · password_eye.dart  # label + validated field; phone and
                                         #   email fields type LTR at the reading start (§8)
    shared_widgets/form_scaffold.dart    # every form screen: safe area + padded scroll + Form
    shared_widgets/app_back_button.dart
    shared_widgets/app_logo.dart         # gradient tile + BrandMarkPainter; LogoLaunch for the splash
    shared_widgets/directional_svg.dart
    shared_widgets/preferences_sheet.dart · preference_option.dart   # language + theme
    shared_widgets/preferences_choices.dart   # the language + theme sections (sheet + settings)
    shared_widgets/preferences_section.dart · preference_option_badge.dart
    shared_widgets/app_confirm_dialog.dart    # showAppConfirmDialog (sign-out, journey endings)
    shared_widgets/app_tab_bar.dart           # the bottom bar (AppTabItem)
    shared_widgets/status_chip.dart           # the status word on a wash of its colour
    shared_widgets/title_bar.dart             # back tile + screen title (`back: false` on a tab)
    shared_widgets/app_empty_state.dart       # icon, title, body, optional action
    shared_widgets/info_note.dart · section_heading.dart
    shared_widgets/link_tile.dart             # icon tile + title + body + chevron
    shared_widgets/point_list.dart            # a titled card of points (guide, About)
    shared_widgets/country_picker_sheet.dart  # showCountryPicker: flag, both names (Profile, Safety)
    theme/app_colors.dart · app_text_theme.dart · app_theme.dart · system_bars.dart
    validation/validators.dart
  features/
    authentication/
      data/models/user_model.dart            # freezed: name, email, phone?, createdAt (no JSON: built from Auth + users/{uid})
      data/models/auth_failure.dart          # the one error the repository throws
      data/repository/auth_repository.dart   # interface — the auth seam
      data/repository/firebase_auth_repository.dart   # Firebase Auth + users/{uid}; also the app's SessionReader
      logic/cubit/auth_cubit.dart            # login / register submission
      logic/cubit/password_reset_cubit.dart  # the forgot-password screen
      logic/cubit/account_cubit.dart         # profile: current user, edit, language, sign-out
      logic/cubit/account_deletion_cubit.dart # the delete-account screen
      logic/cubit/startup_cubit.dart         # where the app opens
      logic/states/auth_state.dart · account_state.dart · startup_state.dart · password_reset_state.dart
      presentation/
        pages/    splash · onboarding · welcome · login · register · forgot_password ·
                  profile (a tab) · edit_profile · settings (language & appearance) · about ·
                  delete_account
        widgets/  splash_{branding,logo,failure,status_slot} · window_anchor ·
                  onboarding_{slide,top_bar,footer,illustration,badges,scene,orbit,
                  eyebrow,dots} · page_parallax · halo_ring{,s} · welcome_{hero,top_bar} ·
                  auth_{header,link_button,notices} ·
                  login_{fields,footer} · register_{fields,footer} · profile_fields ·
                  settings_account_card · password_strength_bar · push_permission_tile
    journeys/                              # home is the journey dashboard, so it lives here
      data/models/journey_model.dart         # freezed: id, origin, destination, departsAt, status,
                                             #   startedAt?, dates; JourneyStatus.isOpen
      data/models/journey_checklist.dart     # the pre-journey checklist's versions and their items
      data/models/journey_draft.dart         # places + departure between plan and review (not stored)
      data/models/journey_failure.dart       # the one error the repository throws
      data/models/location_fix.dart          # a raw fix from the phone + LocationAccess
      data/models/track_point.dart · track_session.dart   # freezed: a trusted route point; one recording
      data/models/tracking_snapshot.dart     # TrackingStatus, RouteSync, SpeedReading, RouteSummary
      data/models/route_math.dart            # haversine, RouteFilter (which fixes to trust), SpeedSmoother
      data/models/potential_incident.dart    # freezed: one potential-incident event + its enums
      data/models/incident_detection_config.dart   # every detection threshold, with its reasoning
      data/models/incident_confidence.dart   # DecelerationEvidence, StopEvidence, the confidence rules
      data/models/safety_check.dart          # freezed: one "Are you okay?" + its state machine
      data/models/escalation.dart            # freezed: the backend's record, read-only
      data/models/journey_place.dart         # freezed: a picked place; JourneyPlaceConverter
      data/models/planned_route.dart · route_progress.dart  # a route, MapFailure; how far along it
      data/models/location_share.dart        # ShareKind, ShareDuration, ShareLinks,
                                             #   ShareRecord, ShareStatus, ShareFailure, ShareGone
      data/models/shared_view.dart           # what a link shows; SharedLiveness, SharedRoutePoint
      data/repository/journey_repository.dart       # interface — the journeys seam
      data/repository/firestore_journey_repository.dart # users/{uid}/journeys, newest 200 on one live query
      data/repository/location_source.dart · geolocator_location_source.dart   # permission, fixes,
                                             #   Android foreground service, iOS background updates
      data/repository/track_store.dart · file_track_store.dart   # the route on the phone first
      data/repository/route_repository.dart · firestore_route_repository.dart  # route chunks + summary
      data/repository/journey_tracker.dart   # THE recording service (one, app-wide; see §16)
      data/repository/tracking_observer.dart # what the tracker tells its observer (fix, tick, …)
      data/repository/incident_detection_engine.dart   # pure detection: deceleration, stop, interruption
      data/repository/incident_monitor.dart  # the observer: engine per journey + event lifecycle
      data/repository/incident_repository.dart   # IncidentRepository + FileIncidentRepository (local)
      data/repository/safety_check_repository.dart # SafetyCheckRepository + FileSafetyCheckRepository
      data/repository/safety_check_service.dart    # eligibility, the 15 s deadline, confirm / time out
      data/repository/safety_notifications.dart    # SafetyNotifications + SafetyAnswerInbox
      data/repository/local_safety_notifications.dart # the notification, its isolate's action
      data/repository/escalation_repository.dart · firestore_escalation_repository.dart # the request
      data/repository/escalation_sync.dart   # reports escalation-ready checks, once each (off on Spark)
      data/repository/journey_account_data.dart # this phone's journey data, on deletion
      data/repository/geocoding_repository.dart · photon_geocoding_repository.dart  # search
      data/repository/routing_repository.dart · osrm_routing_repository.dart        # routes
      data/repository/map_tile_provider.dart · open_free_map_tiles.dart             # tiles
      data/repository/map_style_tuner.dart · map_http.dart  # dark style, ids; provider URLs, GET
      data/repository/location_sharing.dart  # THE publisher (one, app-wide; reads the tracker)
      data/repository/share_repository.dart · firestore_share_repository.dart  # owner's side
      data/repository/shared_view_repository.dart  # recipient's side, read-only
      data/repository/share_link_check.dart  # proves a link works before it is shown
      data/repository/tracker_position_reader.dart # EmergencyPositionReader over the one recording
      logic/cubit/journeys_cubit.dart        # the account's journeys + first name (home, list, plan)
      logic/cubit/plan_journey_cubit.dart    # review's Confirm
      logic/cubit/journey_cubit.dart         # one journey: load, complete, cancel, edit
      logic/cubit/journey_start_cubit.dart   # the checklist: toggle items, start once
      logic/cubit/tracking_cubit.dart        # one journey screen's view of the recording
      logic/cubit/incident_cubit.dart        # the journey's open medium/high movement event; dismiss
      logic/cubit/safety_check_cubit.dart    # the prompt's view of the safety-check service
      logic/cubit/escalation_cubit.dart      # EscalationPhase: what is known of a journey's alert
      logic/cubit/safety_notice_cubit.dart   # whether notifications can reach the user
      logic/cubit/open_escalation_cubit.dart # the journey's unanswered check; "I'm okay"
      logic/cubit/place_search_cubit.dart · place_picker_cubit.dart  # search; the pin
      logic/cubit/route_preview_cubit.dart   # the route between two places
      logic/cubit/journey_map_cubit.dart     # the live map: joins the one recording, reads it
      logic/cubit/share_cubit.dart           # one screen's view of LocationSharing
      logic/cubit/shared_view_cubit.dart     # a recipient's view of one link
      logic/states/journeys_state.dart · plan_journey_state.dart · journey_state.dart ·
                   journey_start_state.dart · tracking_state.dart
      presentation/
        pages/    home · my_journeys · plan_journey · review_journey · journey · edit_journey ·
                  journey_checklist · place_picker · journey_map · sharing · shared_view
        widgets/  home_{header,safety_section} · plan_journey_card ·
                  journey_{list,tile,tile_body,route_card,facts,actions,
                  labels,notices,form,filter_bar,checklist_form} · journeys_content ·
                  place_chips · departure_field · checklist_{item_tile,progress} ·
                  journey_tracking · tracking_{card,in_progress,location,access,stat,
                  duration,labels} · journey_incident · incident_banner ·
                  safety_check_{host,prompt,answer,follow_up} · safety_countdown ·
                  escalation_status · journey_escalation_note · safety_notice_note · app_map · map_{markers,button,
                  credit,defaults,glide,labels,notice} · journey_{planner,planner_form,live_map,map_button,
                  map_controls,map_figures,map_layers,map_panel} · route_{preview_map,
                  summary_line} · place_{pin_button,search_bar,search_results,picker_card,
                  picker_top_bar} · start_sharing_form · manage_sharing · journey_share_card ·
                  share_labels · shared_view_{map,panel}
    safety/
      data/models/trusted_contact_model.dart # freezed: id, fullName, phone, relationship?, createdAt
      data/models/contact_failure.dart       # the one error the repository throws
      data/models/invite_failure.dart · received_alert.dart   # Batch 13's invites; an alert received
      data/models/connection_model.dart      # freezed: one side of a connection; ConnectionStatus
                                             #   (the state machine), ConnectionPermissions
      data/models/connection_invite_model.dart # freezed: an invite; lifetime, statusAt
      data/models/connection_links.dart      # the /c link; tokenOf, tokenIn (what was pasted)
      data/models/connection_access.dart     # ConnectionAccess.allows: the permission evaluator
      data/models/connection_failure.dart    # the one error the repository throws
      data/models/emergency_services.dart    # EmergencyCountry, EmergencyService (types it answers,
                                             #   regional?), Verification, EmergencySource, LocalizedText
      data/models/emergency_directory.dart   # by what happened; regional first; what is missing
      data/models/contact_reach.dart         # can a saved number be called / texted: available,
                                             #   missing, invalid
      data/repository/trusted_contacts_repository.dart        # interface — the contacts seam
      data/repository/firestore_trusted_contacts_repository.dart  # users/{uid}/contacts, one live query
      data/repository/connection_repository.dart   # interface — the connections seam
      data/repository/firestore_connection_repository.dart # invites, accepting, ending; also AccountData
      data/repository/connection_link_check.dart   # proves the invite page is live before a link
      data/repository/contact_invite_repository.dart · cloud_contact_invite_repository.dart
      data/repository/received_alerts_repository.dart · firestore_received_alerts_repository.dart
      data/repository/emergency_data_source.dart   # reads + validates assets/data/emergency_services.json
      data/repository/emergency_repository.dart    # EmergencyRepository + BundledEmergencyRepository
      data/repository/phone_dialer.dart      # PhoneDialer + UrlLauncherPhoneDialer, DialOutcome, DialNumber
      data/repository/message_composer.dart  # MessageComposer + UrlLauncherMessageComposer (sms:),
                                             #   ComposeOutcome — never sends
      data/repository/call_launcher.dart     # THE way to open the phone or messaging app: prepare,
                                             #   one launch at a time
      logic/cubit/connections_cubit.dart     # the connections and invites; every action on them
      logic/cubit/accept_connection_cubit.dart # opening an invite and answering it
      logic/cubit/contacts_cubit.dart        # the list
      logic/cubit/contact_form_cubit.dart    # add, load, save, delete one
      logic/cubit/emergency_cubit.dart       # the chosen country's numbers; dial
      logic/cubit/safety_help_cubit.dart     # Get help: the open escalation, people, Call
      logic/cubit/emergency_location_cubit.dart # "Where you are": known on open, a reading on a tap
      logic/cubit/contact_reach_cubit.dart   # Call / Message on the Trusted Contacts list
      logic/cubit/contact_links_cubit.dart · contact_invite_cubit.dart · received_alerts_cubit.dart
      logic/states/contacts_state.dart · contact_form_state.dart · emergency_state.dart ·
                   contact_invite_state.dart · received_alerts_state.dart ·
                   connections_state.dart · accept_connection_state.dart ·
                   safety_help_state.dart · emergency_location_state.dart
      presentation/
        pages/    safety_center (a tab) · trusted_contacts · contact_form (add + edit) ·
                  safety_guide · journey_safety · emergency_info · received_alerts ·
                  accept_invite (Batch 13) · accept_connection · manage_connection ·
                  safety_help (Get help, Batch 19)
        widgets/  contact_{tile,fields,form_actions,alerts_card,initial} · received_alert_card ·
                  connections_section · saved_contacts_section · connection_{tile,card,
                  invite_tile,ended_tile,access_card,actions,labels} ·
                  manage_connection_form · accept_connection_{entry,offer} ·
                  emergency_{number_tile,service_list,country_header,warning,sources} ·
                  safety_notices · help_{status_card,people_section,person} ·
                  contact_reach_buttons · saved_contact_actions ·
                  emergency_{directory_section,missing_note,location_card,guidance} ·
                  location_reading_lines
docs/
  firebase-architecture.md          # batch 6: the Firebase design and the Batch 7 plan
docs/escalation.md                  # batch 13: flow, channels, privacy, limits, deployment;
                                    #   §11 batch 19: after no answer, the derived lifecycle
docs/PRODUCTION_READINESS.md        # batch 14: what is tested, the findings, the release blockers
docs/maps.md                        # batch 15: map providers, limits, costs, privacy, offline
docs/location-sharing.md            # batch 16: design, security, tokens, costs, limits
docs/connections.md                 # batch 17: relationships, invites, rules, permissions, limits
docs/detection.md                   # batch 18: detection, thresholds, confidence, GPS validation, limits
docs/emergency.md                   # batch 20: numbers and sources, regions, calling, location, limits
hosting/                            # the web pages for links (deployed — §16)
  s.html · share.js · share.css · share-config.js
  c.html · invite.js · invite.css   # where an invite lands without the app; reads nothing
  share-core.mjs · share-core.test.mjs   # its logic, tested with `node --test`
  .well-known/assetlinks.json       # Android App Links; lists the DEBUG key until a release one exists
functions/                          # Cloud Functions, TypeScript (not deployed — §16)
  src/index.ts                      # the four functions, thin: trigger, sweep, two callables
  src/escalation.ts                 # claim (transaction), dispatch, attempts, retry sweep
  src/eligibility.ts                # every check before an alert; limits
  src/channel.ts                    # AlertChannel + FcmChannel (the only channel)
  src/messages.ts                   # what a contact reads, ar + en
  src/invites.ts · requests.ts      # one-time invite codes; caller, fields, error codes
  src/erase.ts                      # what only the backend can delete with an account
  test/                             # node:test on the emulator, fake channel
firebase.json · .firebaserc         # project saferide-a9d9f, functions, rules/indexes paths, emulator ports
firestore.rules                     # the security boundary (§16)
firestore.indexes.json              # one: escalations (status, nextRetryAt) for the retry sweep
                                    # The rules are live (2026-11-05); the index is not deployed
android/app/google-services.json    # generated by flutterfire — identifiers, no secrets
assets/
  translations/{ar,en}.json
  data/emergency_services.json      # every country's emergency numbers, sources, check date (§16)
  icons/                            # SVGs (recoloured at runtime with a ColorFilter)
  images/logo_mark.svg              # the brand mark, single colour
test/                               # mirrors lib/: core/{constants,di,notifications,platform,
                                    # preferences,router,session,shared_widgets,theme},
                                    # features/{authentication,journeys,safety}/{data,
                                    # logic,presentation}
  firestore_rules/                  # Node: firestore.rules against the emulator (`npm test`)
  features/journeys/simulation/gps_script.dart   # synthetic GPS replayed into detection (§14)
  flutter_test_config.dart          # turns off the rings' loop and the launch hand-off (§14)
```

---

## 4. Size and composition — the rules that keep files small

These are the rules the whole codebase is written to. Review against them.

### Size limits

| File | Target | Hard ceiling |
|---|---|---|
| Page | under **150** lines | split before 200 |
| Widget | under **100–150** lines | split before 150 |

When a file passes the target, **extract a widget** — a card, a header, a row,
a footer, a form section. Over the target today: `contact_form_page` (197),
`place_picker_page` (181), `profile_page` (167), `edit_journey_page` (162),
`journey_page` (163) and `login_page` (152) — all under the ceiling; split them before they grow
again.

### Widgets, not methods

**Prefer a widget class over a `_buildX()` method, always.** A widget gets its
own `build`, its own rebuild boundary, `const` construction and a name in the
widget inspector; a method gets none of those and grows the `build` it sits in.

A method is right **only when it is necessary**:

- an **event handler** — `_submit()`, `_next()`, `_append(glyph)`;
- a **pure helper that returns a value**, not a widget — `_copy(part)`,
  `_clock(languageCode)`;
- a small **computed getter** — `bool get _isLast`.

A method that returns a `Widget` is a widget that has not been extracted yet.
The only tolerated exception is a one-line builder inside a list, and even
that is a candidate for a private widget.

### Where a widget lives

1. Used by one screen, small → a **private class** (`_Dot`, `_Eyebrow`) at the
   bottom of the file that uses it.
2. Grows, or used by a second screen of the same feature → its own file in the
   feature's `presentation/widgets/`.
3. Used by a second **feature** → `core/shared_widgets/`.

### Widgets never hold their own content

Every card, chip, row and header takes its text, numbers and colours as
**constructor parameters**. No `Text('…')` literal in a reusable widget; the
page supplies strings from the translation files. That is what makes wiring an
API a repository change instead of a rewrite.

Use `const` constructors wherever possible.

### Pages contain only

`Scaffold`, layout, feature widgets, navigation, and the screen's own event
handlers. No business logic, no API calls, no styling decisions a widget could
own.

---

## 5. Naming

| Thing | Convention | Example |
|---|---|---|
| Files | `snake_case` | `register_fields.dart` |
| Classes | `PascalCase` | `RegisterFields` |
| Variables, methods | `camelCase` | `_isComplete` |
| Pages | `<Thing>Page` | `LoginPage` |
| Cubits / states | `<Feature>Cubit` / `<Feature>State` | `AuthCubit` / `AuthState` |
| Routes | `AppRoutes.<name>` + `<name>Path` | `AppRoutes.login`, `AppRoutes.loginPath` |
| Translation keys | nested by feature | `auth.login.title` |

---

## 6. Packages

**Only what the code uses.** A package is added in the same change as its
first import, with its reason here; one that stops being used is removed in
the change that stops using it.

| Package | For |
|---|---|
| `go_router` | routing, the tab shell (§11) |
| `flutter_screenutil` | `.fx` / `.fsp` design units (§7) |
| `google_fonts` | Cairo (downloaded at first launch — §16 open items) |
| `flutter_svg` | the icons in `assets/icons` |
| `gap` | spacing in rows and columns |
| `easy_localization`, `intl` | translations, plurals, dates and digits (§8) |
| `flutter_bloc`, `equatable` | cubits and their states |
| `get_it` | the service locator |
| `shared_preferences` | `AppPreferences`; easy_localization keeps the locale there |
| `firebase_core` | Firebase initialization (`main`) |
| `firebase_auth` | accounts, the session, password reset (`FirebaseAuthRepository`) |
| `cloud_firestore` | profiles, journeys, contacts, push device records; offline copy |
| `firebase_messaging` | receiving a trusted contact's alert (`PushNotifications`) |
| `cloud_functions` | calling the invite functions (`CloudContactInviteRepository`) |
| `flutter_local_notifications` | the safety check off screen (`LocalSafetyNotifications`); needs core library desugaring and `ActionBroadcastReceiver` in the manifest |
| `freezed_annotation`, `json_annotation` + dev `freezed`, `json_serializable`, `build_runner` | the generated models (`UserModel` without JSON; `JourneyModel`, `TrustedContactModel` read from Firestore) |
| dev `fake_cloud_firestore`, `firebase_auth_mocks` | repository and wiring tests without a network |
| `geolocator` | a journey's route: location permission, fixes, Android's location foreground service, iOS background updates (`GeolocatorLocationSource`) |
| `path_provider` | the app's private support directory for the route recorded on the phone (`FileTrackStore`) |
| `flutter_map`, `latlong2` | the map widget, and the coordinates it uses |
| `vector_map_tiles` (**pinned pre-release** `9.0.0-beta.13`), `vector_tile_renderer` | vector tiles, so a real dark style. The stable line needs `flutter_map` 7 (`docs/maps.md`) |
| `http` | the search and routing providers (`MapHttp`) |
| dev `fake_async` | the search debounce in tests |
| `share_plus` | Sending a share's link through the phone's share sheet (`ManageSharing`) |
| `url_launcher` | Every Call and Message (`UrlLauncherPhoneDialer`, `UrlLauncherMessageComposer`, behind `CallLauncher`): asks whether anything dials or texts, then opens the phone app with the number (`tel:`) or the messaging app with the number and an editable text (`sms:`); the user presses call or send. Nothing dials or sends on its own; no `CALL_PHONE`, no SMS permission |
| dev `flutter_lints`, `flutter_test` | analysis and tests |

⚠️ `freezed` and `json_serializable` share `analyzer` (so will
`retrofit_generator`, §9) — **bump them together**, or `pub get` refuses to
resolve.

Removed after batch 3 because nothing used them: `dio`,
`pretty_dio_logger`, `retrofit`, `retrofit_generator`, `connectivity_plus`,
`cached_network_image`, `shimmer`, `lottie`, `image_picker`, `permission_handler`, `rename`, `cupertino_icons`,
`flutter_launcher_icons`, `flutter_native_splash`. ⚠️ If `permission_handler`
comes back, pin it to `^12`: version 13 needs AGP 9 and fails on this
template's AGP 8.11 ("Unresolved reference: jvmTarget"). `image_picker`
needs iOS `Info.plist` usage keys; `permission_handler` needs iOS `Podfile`
macros. `url_launcher` was removed then and came back in batch 4 with its
first use. `flutter_secure_storage` and `crypto` went in batch 7 with the
local accounts (Firebase keeps the session itself).

⚠️ **Kotlin Gradle plugin 2.3.21** (`android/settings.gradle.kts`): the
Firebase Android SDK is compiled with Kotlin 2.4 metadata, which 2.2 cannot
read ("incompatible version of Kotlin"). 2.3 made `kotlinOptions.jvmTarget`
an error, so `app/build.gradle.kts` uses `kotlin { compilerOptions { … } }`.
⚠️ `firebase_messaging` 17 deprecates `getToken` / `onTokenRefresh` /
`deleteToken`: an install registers with `register()`, its id (the Firebase
Installation ID) arrives on `onRegistered`, and `unregister()` ends it.
⚠️ That registration is **off unless the app opts in**: the Android manifest
has `<meta-data android:name="firebase_messaging_installation_id_enabled"
android:value="true"/>` and iOS `Info.plist` has
`FirebaseMessagingInstallationIdEnabled` = true — without them `register()`
throws "API disabled".

---

## 7. Theming and design units

- Material 3 with the `ColorScheme` written out **explicitly** in `AppTheme`,
  never seeded — a seed invents colours the design never chose.
- `AppColors` holds **roles** (`primary`, `textMuted`, `border`, `error`), not
  colour names. It is a `ThemeExtension` with two instances, `AppColors.light`
  and `AppColors.dark` (values and names from the SafeRide spec's palette
  tables), installed by `AppTheme.light()` / `AppTheme.dark()`. Widgets read
  **`context.appColors.<role>`** — never `AppColors.light.x` and never a
  `Color(0x…)` literal: a colour that does not come through the theme does not
  change in dark mode.
- `appColors.tint(role)` is an opaque quiet wash of a role over the surface
  (badges, illustration panels, selected rows); its strength is per palette.
  Alpha on a role (`secondary.withValues(alpha: …)`) is fine for decoration; it
  is not a new colour.
- A field added to `AppColors` must also go into `copyWith` **and** `lerp`, or
  that role stops animating — and silently stays the old value — when the theme
  changes.
- SVG icons in `assets/icons` carry the colour they were exported with. Give
  every `SvgPicture` / `DirectionalSvg` a `ColorFilter.mode(<role>,
  BlendMode.srcIn)`, or it stays light-mode navy on a dark screen.
- Text styles come from `context.texts.<role>` and are adjusted with `copyWith`.
  `AppTextTheme.of(colors)` colours them from the active palette.
- `ThemeMode` (light / dark / system) lives in `PreferencesCubit`, which is read
  synchronously before the first frame — the app never paints a light frame
  before a dark one.
- The app draws edge to edge (`main.dart`); `SystemBars` keeps both system bars
  transparent with icons readable on the active theme, and every screen pads
  itself with `SafeArea`. A bottom sheet adds the bottom inset itself
  (`showModalBottomSheet(useSafeArea: true)` only guards the top).
- Spacing / radius for chrome with no design behind it: `AppSpacing`,
  `AppRadius`. Durations: `AppDurations`.

### Motion

The spec asks for restrained, polished motion that never delays a task. The
tokens are `AppDurations` (lengths), `AppCurves` (five curves, none
overshoots — `app_motion_test` samples them) and `AppMotion` (offsets,
distances). No screen writes a literal duration or curve.

- **Entrances.** A screen wraps its content in one `EntranceScope` (a single
  finite clock, `AppDurations.entrance`) and each piece in an `EntranceItem`
  on a beat (`AppMotion.beat(n)`: 140 ms + n × 60). Paint only — taps and
  semantics work from frame 0. It plays once per arrival, never replays on a
  rebuild or a pop back, and jumps to its end when covered mid-run.
- **Routes.** Every route is an `AppPages` page (§11): `stage` fades through
  for `go`, `task` slides 30 from the end side for `push`. Never mix in a
  `MaterialPage` — a mixed stack breaks the covered page's secondary
  animation.
- **The seal.** One Hero tag, `BrandSeal.tag` (`brand-seal`), with a straight
  `RectTween` and a single-shape shuttle (a plain Hero arcs and distorts the
  tile). It flies splash → welcome and splash → onboarding badge; never out
  of onboarding, and never to home (the dashboard has no logo to land on —
  the seal leaves with the splash). The shuttle's animation arrives already
  curved — never curve it again; the tile ↔ badge glyph crossfade runs on the
  route's linear time.
- **The brand mark has three copies:** `assets/images/logo_mark.svg` (the
  source), `BrandMarkPainter` (drawn in Dart, so the splash can move the lane
  dashes) and `drawable/ic_launcher_foreground.xml`. `brand_mark_test` diffs
  them; change all three together.
- **The rings never stop** (`HaloRings`, welcome and onboarding): they breathe
  in a slow wave that rolls outward (`AppMotion.haloBreaths` per
  `AppDurations.haloCycle`) and the dotted orbit turns once per cycle, with
  the reading direction. It is the **one** animation in the app that loops.
  One controller and one `RepaintBoundary`; a frame repaints only the rings.
  `TickerMode` pauses it when covered or in the background.
- **Tabs** fade through on `AppDurations.short` (`AppTabShell`); the
  navigators stay stacked in place, so none loses its state, and only the
  shown one ticks.
- **Reduced motion** (`context.reduceMotion`, Android's "Remove animations"):
  every screen is at rest on frame 1, route durations are zero, Hero flights
  are off, the rings stand still.
- Nothing else loops, pulses or bounces, and nothing moves in a way that
  suggests live tracking (no radar ripple, no moving route line) — §16.

### Figma → Flutter units

Write the number that is **literally in the design** and append `.fx` (size,
spacing) or `.fsp` (font size):

```dart
Gap(24.fx)
fontSize: 15.fsp
```

`AppDesign.width / height` is the frame the app lays out at;
`AppDesign.figmaFrameWidth` is how wide that frame is **in the Figma file**.
They are equal for a board drawn at real size. When a board is drawn at a scale
(PrepAI's phones were 168.8pt wide for a 390pt layout), set
`figmaFrameWidth` to the board's width and every `.fx` converts on its own.
**Never pre-multiply by hand** — it hides the source value and puts the scale
factor in two places.

⚠️ `ScreenUtil` reads the window size **once at startup**; resizing a desktop
window afterwards does not rescale. Verify layout on a phone or an emulator.

---

## 8. Localization

- `easy_localization`, files in `assets/translations/{ar,en}.json`.
- **Add every key to both files in the same edit.** Keys are nested by feature.
- **No start locale.** easy_localization picks the language the user chose
  (`context.setLocale` saves it under `locale` in shared_preferences), else the
  device language when it is Arabic or English, else English, the fallback. A
  saved choice is never overridden by the device. Do not mirror the locale into
  `AppPreferences` — two copies drift.
- **In widgets, translate with `context.tr('key')`**, not `'key'.tr()`. The
  context form registers a dependency on `Localizations`, so the widget rebuilds
  when the language changes live (the preferences sheet does that without a
  restart). The string form reads a global: a `const` widget built with it keeps
  the old language until something else happens to rebuild it. `'key'.tr()` /
  `.plural()` stay only outside the widget tree — `Validators` (run at validate
  time), the back dispatcher, `onGenerateTitle`.
- Language names are written in their own script in **both** files
  (`preferences.languages.ar` is «العربية» in `en.json` too).
- **Never hardcode left / right.** Use `EdgeInsetsDirectional`,
  `AlignmentDirectional`, `start` / `end`, or `context.isRtl` when logic truly
  depends on direction.

⚠️ **Every `EasyLocalization` passes `assetLoader: const AppAssetLoader()`**, in
tests too. `ar.json` is over 50 KB, and `rootBundle.loadString` hands anything
that size to a background isolate: a widget test's fake clock never sees it
finish, so the Arabic tests fail with empty strings.

### Plurals

A count and its noun are a **translation**, not a concatenation. Counted strings
are plural maps and are read with `.plural(count, namedArgs: …)`:

```json
"minLength": { "one": "…حرف واحد", "two": "…حرفين", "few": "…{count} أحرف",
               "many": "…{count} حرفًا", "other": "…{count} حرف" }
```

⚠️ **`main.dart` sets `ignorePluralRules: false`, and it must stay.** The
package defaults it to `true`, which replaces the CLDR rules with a
zero/one/two/other match on the value — Arabic's `few` and `many` are then never
read, and «٣ نماذج» prints as «٣ نموذج» while the JSON looks correct.

⚠️ English has **no `zero` category** — 0 resolves to `other`. A sentence that
must read differently at zero ("less than a minute") is its own key.

### Digits

`LocaleNumbers.decimal(languageCode)` formats in the digits the design draws;
`LocaleNumbers.dateTime` does dates the same way (needs
`initializeDateFormatting()`, called in `main` and `flutter_test_config`).
The date and time pickers draw their own digits from their locale, so they
get `LocaleNumbers.pickerLocale` (`ar_EG` for Arabic) — `showDatePicker(locale:)`,
and `Localizations.override` around the time picker.
⚠️ CLDR gives **Latin** digits for `ar` and `ar_SA`; `ar_EG` is used purely as
the numbering system to get Arabic-Indic (`٨`). Delete that substitution if a
design uses Latin digits. Pad a number on the Latin string **before** swapping
digits, or the padding lands in the wrong script.

### Bidi

⚠️ **A Latin run, a code, or a number with neutral punctuation inside Arabic
text gets reordered.** `0:28` rendered as `٢٨:٠`, `#TR-1048` as `TR-1048#`.
Wrap the fragment in a left-to-right isolate (U+2066 … U+2069), built with
`String.fromCharCode` so the invisible marks are visible in code review — see
`ContactTile._ltr` (phone numbers). For a value that may be either script, use a
first-strong isolate (U+2068 … U+2069) — every journey place goes through
`JourneyLabels.place`. The Arabic comma `،` is a strong
character; `·` between Arabic and a number is not, and drifts.

⚠️ An **input** is not fixed by an isolate: an RTL text field types
`+966…` as `…966+`. `AppTextField` gives phone and email fields
`textDirection: ltr` and `hintTextDirection: ltr` — a new keyboard type that
holds Latin text belongs in that check. Their alignment is **physical**
(`TextAlign.right` in Arabic, `left` in English): the field's `textAlign`
also places its hint, helper and error, which resolve it in the page's
direction while the text resolves it in LTR, so `end` lands the value on
the right and the error on the left. It is the one place outside the brand
tile where left / right is written, chosen by `context.isRtl`.

---

## 9. Wiring a backend later — Retrofit + freezed + json_serializable

> **SafeRide's backend is Firebase** (decided in batch 6, wired in batch 7).
> Its design — Auth, Firestore structure and rules, FCM, Cloud Functions,
> App Check, costs, platform setup — is in
> [`docs/firebase-architecture.md`](docs/firebase-architecture.md); §16 says
> what is built. The Retrofit recipe below stays for a REST API, should the
> project ever need one; Firebase does not use it.

⚠️ **The base contains no code for this, and the networking packages are
not installed.** Add `dio`, `retrofit`, `pretty_dio_logger` (and
`connectivity_plus` if offline handling is wanted) plus dev
`retrofit_generator` in the change that wires the first endpoint.
`build.yaml` already sets `explicit_to_json`; everything below is the
documented method, so every project wires it the same way.

**Proven on this base before the networking code was removed:** a freezed model
with a nested list and a Retrofit service generated with `build_runner`, the
nested list serialized through its own `toJson()`, and `flutter analyze` stayed
clean.

### 0 · The core network files

`build.yaml` sets `explicit_to_json: true` — without
it nested models are sent as raw objects and the request body breaks silently,
so **do not remove it**.

Create `core/network/` (`api_constants.dart`, `dio_factory.dart`,
`api_error.dart`) and `core/di/service_locator.dart`:

```dart
// dio_factory.dart — the only place a Dio is built
abstract final class DioFactory {
  static Dio create() {
    final Dio dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
    // interceptors: refresh FIRST, then auth (see the rules below)
    if (kDebugMode) dio.interceptors.add(PrettyDioLogger(requestBody: true));
    return dio;
  }
}

// api_error.dart — the one error type every repository throws
enum ApiErrorCode { network, timeout, unauthorized, forbidden, notFound,
                    validation, server, unknown }

class ApiError implements Exception {
  const ApiError({required this.code, this.message = '', this.statusCode,
                  this.fieldErrors = const <String, List<String>>{}});
  factory ApiError.fromDio(DioException e) { /* map type + status to a code,
      read the body's message and its 422 per-field details */ }
  final ApiErrorCode code;
  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;   // shown under each input
}

// service_locator.dart
final GetIt sl = GetIt.instance;
Future<void> setupServiceLocator() async {
  sl.registerLazySingleton<Dio>(DioFactory.create);
}
```

…and call `await setupServiceLocator();` in `main` after
`EasyLocalization.ensureInitialized()`.

The pipeline, per feature, when its first endpoint is wired — in this order:

`ApiConstants` → `data/models` → `data/repository` (Retrofit service + repository)
→ `logic/states` → `logic/cubit` → DI → page.

### 1 · The endpoint

```dart
// core/network/api_constants.dart
static const String login = '/auth/login';
```

Base URL is a build-time define, never a committed literal:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

### 2 · The model (freezed 3 needs `abstract class`)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    @JsonKey(name: 'expires_in') @Default(0) int expiresIn,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}
```

Nullable where the API can send null — **null is not zero** (a progress of `null`
means "not started", `0` means "started, nothing done"; the UI draws them
differently).

### 3 · The Retrofit service

```dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String? baseUrl}) = _AuthApi;

  @POST(ApiConstants.login)
  Future<AuthSession> login(@Body() Map<String, dynamic> body);
}
```

### 4 · The repository — the one place `DioException` becomes `ApiError`

In SafeRide `AuthRepository` is already an interface (§2, §16), so the API
version is one more implementation of it, swapped in by the service locator:

```dart
class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api);
  final AuthApi _api;

  Future<AuthSession> login(String identifier, String password) async {
    try {
      return await _api.login(<String, dynamic>{
        'identifier': identifier,
        'password': password,
      });
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
```

A cubit never sees a `DioException`; it branches on `ApiError.code` and shows
`ApiError.fieldErrors` under the matching inputs.

### 5 · States — `sealed` + `Equatable`

```dart
sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => const <Object?>[];
}
final class AuthInitial extends AuthState { const AuthInitial(); }
final class AuthSubmitting extends AuthState { const AuthSubmitting(); }
final class AuthSucceeded extends AuthState { const AuthSucceeded(); }
final class AuthFailed extends AuthState {
  const AuthFailed(this.error);
  final ApiError error;
  @override
  List<Object?> get props => <Object?>[error.code, error.message];
}
```

### 6 · The cubit — no `BuildContext`, no widgets, no navigation

```dart
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthInitial());
  final AuthRepository _repository;

  Future<void> login(String identifier, String password) async {
    emit(const AuthSubmitting());
    try {
      await _repository.login(identifier, password);
      emit(const AuthSucceeded());
    } on ApiError catch (e) {
      emit(AuthFailed(e));
    }
  }
}
```

### 7 · DI

```dart
sl
  ..registerLazySingleton<AuthApi>(() => AuthApi(sl<Dio>()))
  ..registerLazySingleton<AuthRepository>(() => ApiAuthRepository(sl<AuthApi>()))
  ..registerFactory<AuthCubit>(() => AuthCubit(sl<AuthRepository>()));
```

Services and repositories are lazy singletons; cubits are **factories** — one
per screen.

### 8 · The page

Provide the cubit, call it from the handler, navigate from a listener:

```dart
BlocProvider<AuthCubit>(
  create: (_) => sl<AuthCubit>(),
  child: BlocConsumer<AuthCubit, AuthState>(
    listener: (context, state) {
      if (state is AuthSucceeded) context.goNamed(AppRoutes.home);
    },
    builder: (context, state) => /* form; busy: state is AuthSubmitting */,
  ),
)
```

Keep the client validation (§10) **and** show the server's `422` field errors
under the same inputs — the server is the authority and knows things the phone
cannot (an email already taken).

### 9 · Generate

```bash
dart run build_runner build --delete-conflicting-outputs   # or: watch
```

Generated `*.freezed.dart` / `*.g.dart` are committed; never edit them.

### When auth becomes real — the rules PrepAI paid for

- **Tokens in `flutter_secure_storage`**, the access token also kept in memory.
- **Interceptor order in `DioFactory`: refresh first, then auth.** Stamping
  first attaches the stale token and refreshes too late.
- **One refresh at a time** — a single-flight `Completer`. A screen firing four
  requests gets four `401`s; four refreshes each send a refresh token the first
  already rotated away, and the session dies right after a successful login.
- **The refresh call uses a bare `Dio`**, not the intercepted one, or a `401` on
  refresh recurses.
- **Refresh a minute before `expires_in`**, not only after a `401`; keep the
  `401` path too — it is the only thing that catches a token revoked
  server-side. Store the deadline in UTC.
- **A `403` for the wrong token type signs out; it never refreshes** — the retry
  fails identically, forever.
- **Money is `int` minor units** (`19900` = 199.00). One `double` and totals
  drift.
- **`Accept-Language` on every request** if the API localizes content. An
  interceptor has no `BuildContext`, so mirror `context.locale` into a static
  holder in `App.build`.
- **"Cannot reach the server" is not "signed out".** On the splash, a network
  or timeout failure with a stored session goes to an offline state, never back
  to onboarding.

---

## 10. Validation

`core/validation/validators.dart`, used as `Validators.of(context).password`.
This is the part of the base meant to be reused as-is.

| Rule | Applies to |
|---|---|
| required | every mandatory field |
| email — `name@domain.tld` | login, register |
| full name — at least 2 letters after collapsing spaces, at most 200 | register, edit profile, trusted contact |
| phone — optional; `+` then 7–20 digits, spaces, `-`, `()` | register, edit profile (never verified) |
| contact phone — required, then the phone rule | trusted contact |
| relationship — optional, at most 40 | trusted contact |
| password — 8–128 characters, a digit, an uppercase letter; the first unmet rule is shown | register |
| confirmation matches the password | register |
| presence only | login's password |
| place — 2 to 120 characters; the destination differs from the start, ignoring case | plan / edit a journey |
| departure — required; not in the past (a minute's grace); an edit keeps its stored departure even once passed (`departure(kept:)`) | plan / edit a journey |

- The rules came from a real backend's schema (PrepAI's), so a value the form
  accepts is a value such a server accepts. Change the patterns and limits in
  `Validators` — every form reads them from there.
- Forms use `Form` + `GlobalKey<FormState>` + `AppTextField(validator: …)`.
  `autovalidateMode` starts `disabled` and becomes `onUserInteraction` after the
  first failed submit: errors before anyone has tried are noise, errors that do
  not clear as you fix them are worse.
- **Login checks presence only** — the password policy is for creating a
  password, and an old one may predate it.
- `confirm(() => _password.text)` reads the other field **at validation time**;
  capturing the value when the form is built compares against an empty string.
- `Validators.passwordScore` drives `PasswordStrengthBar` with the **same three
  rules**, so a full bar means the password will be accepted.
- Length messages are plurals with locale digits: «يجب ألا يقل عن ٨ أحرف».
- **What the repository knows, the form shows under the field**: a taken
  email (register), a wrong password (login) and a contact's number already
  in the list go through
  `AppTextField(errorText:)` and clear when the field changes. Only an error
  with no field to sit under (no such account, storage) is a notification.

---

## 11. Routing

- `go_router`, configured in `core/router/app_router.dart`; names and paths in
  `AppRoutes`. **Navigate by name**, never with a raw path.
- **`push`** stacks a screen the user can step back from. **`go`** replaces the
  stack — use it when stepping back would be wrong: leaving the splash,
  finishing onboarding, signing in or out, and any screen after a payment
  or a submission. Login ⇄ register replace each other
  (`pushReplacementNamed`), so back from either still means welcome.
- Small data for the next screen travels as `extra`. An id that must
  survive a restart is a **path parameter**.
- ⚠️ **A route that gains a path parameter breaks every navigation that does not
  pass it — silently**: the tap does nothing, no exception, no log. Grep every
  call site after adding one.
- ⚠️ A literal path segment is what keeps `/thing/:id` from swallowing
  `/thing/result`. Prefer `/thing/view/:id`.
- ⚠️ A sheet-style route needs `CustomTransitionPage(opaque: false)`, or Flutter
  stops painting the page underneath and the "dim" is an empty dark screen.

### The back button

`AppBackButtonDispatcher` makes Android's back gesture mean **back** on every
screen. A screen reached with `go` has nothing to pop; without the dispatcher
the gesture falls through to the launcher and the app "closes from the middle".
The router is asked first; only when it popped nothing does the dispatcher look
up where "up" is (`_up`), and it never returns `false`. Splash, onboarding,
welcome and home are the ends of the road: the first back shows «اضغط رجوع مرة
أخرى للخروج» (an `AppNotifier` info notice, `exitWindow` long), a second
within `AppDurations.exitWindow` leaves.

Today `_up` sends login and register to **welcome** and forgot-password to
**login**; My Journeys, Safety,
Profile and plan to **home**; review to plan; a journey, its edit screen
and its checklist to My Journeys; the contacts list, the guide, journey safety, emergency
information and Get help to Safety; add / edit contact to the contacts list; edit
profile, settings and About to Profile. Welcome never leads back
to onboarding: once onboarding is finished it is reached only by a fresh
install.

A share's link opens `/s` with nothing beneath it: back goes to the splash, which
decides (`SharedViewPage.leave`, for the screen's own button too: `AppBackButton`
can only pop). The token is the link's `#` part (`state.uri.fragment`). An invite's
link opens `/c` the same way (`AcceptConnectionPage.leave`); with no token that
route asks for a paste. After accepting, the page `go`es to Safety and pushes
Trusted Contacts, so the list's own back has somewhere to go.

**When you add a `go` target, add its line to `_up`.** Destinations take no path
parameters — the ids went with the stack.

A screen that wants back to mean something of its own (onboarding: back = the
previous step) uses `PopScope(canPop: false, onPopInvokedWithResult: …)`.
go_router's `popRoute` calls `NavigatorState.maybePop()`, which honours it, so
the dispatcher's `super.didPopRoute()` returns `true` and nothing else happens.
On onboarding's first step `canPop` is `true` and the exit warning takes over.

The dispatcher takes an injectable `clock` (default `DateTime.now`) so the exit
window can be tested in fake time.

⚠️ **Predictive back is switched off on purpose**
(`android:enableOnBackInvokedCallback="false"` on `<application>`). From
targetSdk 36 on Android 16, predictive back is the default. Flutter then claims
back only while the navigator can pop; on a single-route screen (splash,
onboarding step 1, welcome, home, or anything reached with `go`) the system
takes the gesture and closes the app, and `popRoute` never reaches the
dispatcher. Widget tests cannot see this: they call `handlePopRoute()`
directly, which is the step the engine skips. A manifest test keeps the
attribute in place. Turning predictive back on means keeping
`frameworkHandlesBack` true on every exit route instead.

⚠️ **`MaterialApp.router` is given the router in pieces** (`routerDelegate`,
`routeInformationParser`, `routeInformationProvider`, `backButtonDispatcher`),
never `routerConfig` plus a dispatcher. That combination is rejected by an
`assert` — and asserts are stripped from release builds, so it silently does
nothing exactly where it matters. PrepAI found this only by testing the release
APK.

Verified on an API 36 emulator (debug build): back from login → welcome;
an open keyboard closes before anything
pops; on onboarding the first back warns and a quick second one leaves.
Release build (batch 4): Emergency information → Safety → Home, About →
Profile.

### Signed in: the tab shell

`StatefulShellRoute` with four branches — Home (`/home`), My Journeys
(`/journeys`), Safety (`/safety`), Profile (`/profile`) — drawn by
`AppTabShell`. Signing in, registering and the splash `go` to `home`. Plan
(`/plan`), review (`/plan/review`, `extra`: a `JourneyDraft` map; without it
the route redirects to plan), a journey (`/journey/view/:id`), its edit
screen (`/journey/edit/:id`), the safety screens (`/safety/contacts`,
`/safety/contacts/new`, `/safety/contacts/edit/:id`, `/safety/guide`,
`/safety/journeys`, `/safety/emergency`, `/safety/help`) and the profile screens
(`/profile/edit`, `/profile/settings`, `/profile/about`) are top-level, so
they open over the tab bar. Confirming a plan does `goNamed(home)` then
`pushNamed(journey)`: plan and review leave the stack, and back from the
details is home. `AppRouter.create()` builds a fresh router; tests use it.

### Pages

Every `GoRoute` uses a `pageBuilder` returning `AppPages.stage` (splash,
onboarding, welcome, the four tab roots — and the shell itself) or
`AppPages.task` (everything pushed); `app_pages_test` fails on a route with a
plain `builder` and counts the routes (35). The
dispatcher's "up" `go` passes `extra: AppPages.up`, which makes a task page
arrive with the stage fade, so going back never looks like going forward.
`MaterialApp.builder` paints a root `ColoredBox(appColors.background)` under
every route, so a fade-through never shows the window's own colour.

---

## 12. Android release gotchas

- **A share's link and an invite's** have an intent filter on
  `https://saferide-a9d9f.web.app`, paths `/s` and `/c`, with `autoVerify`.
  Verification needs `hosting/.well-known/assetlinks.json` live
  with the signing key's fingerprint. It lists this machine's debug key: add the
  release key's when one exists, or store builds open links in the browser.
- **Backups are off** (`android:allowBackup="false"`): route points and the
  install id must not reach a cloud backup or a restored phone.
- **Release signing.** `android/key.properties` (`storeFile`, `storePassword`,
  `keyAlias`, `keyPassword`; never committed) signs a release; without it the
  debug key does, which the stores refuse.
- **Safety notifications (batch 13).** `flutter_local_notifications` needs
  `isCoreLibraryDesugaringEnabled` and `desugar_jdk_libs` in
  `app/build.gradle.kts`, and `ActionBroadcastReceiver` in the manifest, or
  "I'm safe" does nothing. **`USE_FULL_SCREEN_INTENT` is deliberately
  absent** (`docs/escalation.md` §2).

- **Route recording (batch 9).** The manifest has `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE` and
  `FOREGROUND_SERVICE_LOCATION`; geolocator's own manifest declares its
  `GeolocatorLocationService` with `foregroundServiceType="location"`.
  **`ACCESS_BACKGROUND_LOCATION` is deliberately absent**: a location
  foreground service started while the app is on screen keeps reading with
  the while-in-use permission. ⚠️ geolocator creates the notice's channel
  at `IMPORTANCE_NONE`; Android raises a foreground service's channel to
  low importance, but **only shows the notice when the app holds
  `POST_NOTIFICATIONS`** (Android 13+) — so the "Allow location" tap also
  asks for it, once, and a start waits until both prompts are answered (a
  recording started while the second prompt is open posts its notice
  before it is allowed, and Android never posts it again). The notice's
  icon is `drawable/ic_launcher_foreground` (white on transparent). Google
  Play requires the location foreground-service type to be declared, with
  a video, in the Play Console before release.

- **Call and Message need `<queries>` entries** (`VIEW` + `tel:`, `VIEW` +
  `sms:`) for `canLaunchUrl` to answer on Android 11+ — without them every
  phone reads as "can't dial / can't text". iOS has
  `LSApplicationQueriesSchemes: tel, sms` for the same reason.
  `platform_config_test` checks both, and that no permission to call, text
  or read either is declared.

- ⚠️ **INTERNET permission is in the main manifest on purpose**, even with no
  backend. Flutter's template declares it only in `src/debug` and
  `src/profile`, so a release APK without it has **no network at all** —
  `google_fonts` cannot fetch Cairo, remote images do not load, and later every
  request fails as "no connection" on a phone that plainly has internet.
- **A plain-HTTP dev API needs a cleartext exception** in a release build
  (`res/xml/network_security_config.xml` + `android:networkSecurityConfig`),
  scoped to the dev host. `dio` ignores Android's cleartext policy, native
  players do not — "the API works" does not prove media will load. Remove both
  before a build that reaches real users; production is HTTPS.
- **Portrait is locked twice** — `SystemChrome` in `main.dart` and
  `android:screenOrientation="portrait"` in the manifest, which stops the window
  rotating before Flutter starts. The sizing system scales against a portrait
  frame; landscape needs its own design.
- A phone reaching a dev server on the laptop needs the laptop's **LAN IP**
  (DHCP — it changes), both on the same Wi-Fi, and the host firewall open. A
  corporate access point often blocks device-to-device traffic outright;
  `adb reverse tcp:8000 tcp:8000` over USB sidesteps all of it.
- A launch window that should be white in dark mode needs
  `drawable-v21/launch_background.xml`, `values-night/styles.xml` **and**
  `values-v31` (`windowSplashScreenBackground`) — or use
  `flutter_native_splash`, which writes all three. SafeRide does it by hand:
  `@color/launch_background` (`values/colors.xml` light `#F7F9FC`,
  `values-night/colors.xml` `#0B1220`, the Flutter splash's own background)
  feeds both `launch_background.xml` files, `NormalTheme`'s window background
  and `values{,-night}-v31` `windowSplashScreenBackground`. The adaptive icon is
  `mipmap-anydpi-v26/ic_launcher.xml` over `@color/ic_launcher_background`
  (`#142B4A`) with `drawable/ic_launcher_foreground.xml` — the logo mark's
  paths copied **unchanged** from `assets/images/logo_mark.svg` inside a scaling
  group, so the two can be diffed. Change the mark in both places.
- **The launch hand-off (API 31+).** The system splash draws the adaptive
  icon in a 160 dp disc (`windowSplashScreenIconBackgroundColor` =
  `@color/ic_launcher_background` in both `values{,-night}-v31` styles); the
  `launch_background.xml` files draw the same disc for API 24–30 (not yet
  verified — no API 24–30 image here). Flutter's splash frame 0 repeats it
  (`AppMotion.launchDisc` 160 dp, `launchGlyph` 128 dp — measured within 1 px
  on API 36). `MainActivity` removes the system splash at once in
  `setOnExitAnimationListener` and answers `LaunchHandoff.wait()` over the
  `safe_ride/launch` channel; the splash intro starts then (at most
  `LaunchHandoff.timeout` later). Without it the intro ran behind the system
  splash — a cold start's first frame took 55–540 ms to raster on the
  emulator — and showed through its exit fade as a double image.
- **Refresh rate.** `MainActivity.preferFastestRefreshRate` asks for the
  display's fastest mode at the current resolution; some phones keep an app
  at 60 Hz unless it asks. Not yet verified on a 90/120 Hz device: the
  emulator has a single 60 Hz mode.
- ⚠️ The native launch colour follows the **system** night mode, not the app's
  theme choice. A user whose in-app theme differs from the system sees one
  colour change at launch. Matching it needs native code
  (`UiModeManager.setApplicationNightMode` on API 31+).

---

## 13. Layout traps — only visible at run time

1. `Container(alignment: …)` with no explicit size **grows to fill** whatever it
   is given — inside a bottom bar a button swallowed the screen. Use
   `Center(heightFactor: 1)` when you only want the child centred.
2. In a `Row`, `Flexible(title)` beside `Expanded(label)` splits the width and
   truncates the title. Put `Expanded` on the part that absorbs the slack.
3. A band drawn **behind** the body with a fixed top offset hides text the day
   the copy is longer than the design's. Let the band size itself and overlap
   the next block with `Transform.translate`.
4. A caption with `maxLines: 1` that fits in Arabic may not in English
   ("Questions sol…"). Test both languages.
5. A widget whose `Timer` is keyed to a prop must re-arm in `didUpdateWidget` —
   the same widget instance is reused when the prop changes.
6. A `DecoratedBox` with rounded corners does not clip its child; add
   `clipBehavior` or a `ClipRRect` when content has a background of its own.

7. A text field, tile or row with a fixed height holds text only at 1.0× font
   scale. Use a minimum height (`BoxConstraints(minHeight: …)`) and let it grow;
   check at `adb shell settings put system font_scale 2.0`.
8. A screen with content at the top and actions at the bottom is a
   `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)`, not a
   `Column` with `Spacer` — the column overflows on a small phone at large text
   (see `WelcomePage`).

9. A `Semantics(button: …)` or `Semantics(header: …)` **without
   `container: true` merges into its parent** with the text around it:
   TalkBack then reads a card's body and its button as one node, and the
   button is not a target of its own. Every button-like or heading
   `Semantics` in the app sets `container: true` (`AppPrimaryButton`, the
   tab bar, the avatar, the notification's close button, the headings).
   `find.bySemanticsLabel` in a test catches it — it fails on a merged node.

The analyzer catches none of these. **Render every new screen, in both
languages and both themes.**

---

## 14. Verification

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # once a model or service exists
dart format lib test
flutter analyze                                             # must be clean
flutter test                                                # must pass
flutter build apk --debug
```

`test/flutter_test_config.dart` runs before every test file and turns off
two things a widget test cannot wait for: `HaloRings.ambient` (a loop never
settles, so every `pumpAndSettle` on welcome or onboarding would time out)
and `LaunchHandoff.enabled` (a platform channel). `halo_rings_test` and
`launch_handoff_test` turn each back on.

⚠️ A platform-channel reply, and a `Completer` made in `setUp`, complete on
the **real** event loop, which a pumping widget test never yields to — await
`tester.idle()` before pumping, and make test completers inside the test.
⚠️ `AnimatedSize(duration: Duration.zero)` asserts in its own layout; under
reduced motion leave the `AnimatedSize` out instead.

A test that builds journey or safety screens uses the real
`AppRouter.create()` and the Firestore repository over
`FakeFirebaseFirestore` with a fake `SessionReader`. Every `SessionReader`
fake needs a `changes` stream (`const Stream<void>.empty()` when nothing
renames). `service_locator_test` runs the app's real wiring
(`setupServiceLocator(auth:, firestore:, messaging:)` over
`firebase_auth_mocks` and `fake_cloud_firestore`) across two accounts: each
sees only its own journeys and contacts, by list and by id, and preferences
survive both sign-outs. ⚠️ `MockFirebaseAuth` signs in whichever user was
created last whatever the email — set `mockUser` before a login — and emits
its first auth state only to the first listener, so tests over it avoid
`hasSession()`. Its `whenCalling` needs a package it does not export; error
mapping is tested through a small throwing `FirebaseAuth` fake instead. A
test that builds login, register or the profile screens registers their
cubits in `sl` (`AuthCubit`, `PasswordResetCubit`, `AccountCubit`,
`PushPermissionCubit`) over fakes; a fake that implements only what it needs
extends `Fake`. A test that shows a notification lets its timer run out
before it ends, or the test fails on a pending timer.

**The backend** is tested in `functions/test/` with the real Admin SDK on
the Firestore emulator and a fake `AlertChannel`, so no message can leave:

```bash
cd functions && npm install && npm test   # Firebase CLI + JDK 21
```

⚠️ `fake_cloud_firestore` runs a transaction as plain sequential calls: no retries,
no conflicts, no refusals. A test on it says nothing about those; **run anything
that uses a transaction on the emulator too** (`docs/connections.md` §7 is what that
found). In a widget test, a future made under `tester.runAsync` finishes on the real
event loop: loop `pump` and `runAsync(pumpEventQueue)` until it has
(`connections_screens_test`).

**Detection** is replayed, not guessed: `GpsScript` builds a journey (drive,
brake, drop, hold, crawl, turn, gap, pause, jump, stale, repeated and late
fixes, poor accuracy, missing speed) and plays it into the engine, the monitor
or the safety check with the tracker's 5 s ticks (`detection_scenarios_test`).
A new threshold changes the replays, never the other way round.

**The web viewer's logic** runs with no browser:

```bash
node --test hosting/share-core.test.mjs
```

**Security Rules** are tested in `test/firestore_rules/` against the
Firestore emulator — owner allowed; another user, signed out, forged fields
and forbidden status changes denied:

```bash
cd test/firestore_rules && npm install && npm test   # Firebase CLI + JDK 21 (JAVA_HOME and PATH)
```

⚠️ The Firebase emulators refuse Java below 21 — and they run the `java` on
`PATH`, so put the JDK 21 `bin` first there too; `JAVA_HOME` alone is not
enough when an older Java is installed. ⚠️ The desktop app's
Terminal panel sees a different `AppData` from Bash: the npm-global
`firebase` is not on its PATH, and PowerShell blocks `npx.ps1` — use
`npx.cmd --yes firebase-tools@<version> …` there (interactive commands such
as `firebase login:add` need that terminal).

Tests run without `AppTheme`: `google_fonts` would try to download Cairo. A
widget test builds a plain `ThemeData(extensions: [AppColors.light])` (and
`AppColors.dark` for `darkTheme`) inside `ScreenUtilInit` + `EasyLocalization`.
⚠️ Call `rootBundle.clear()` in `setUp` of any test that loads translations:
the asset bundle caches each file as a `Future` made in the first test's
fake-async zone, and every later test awaits a future that never completes —
the app silently never builds. Seed `SharedPreferences.setMockInitialValues`
with `{'locale': …}` so a test does not depend on the machine's language.

`flutter analyze` clean and `dart format` unchanged are the floor, not the
proof. Run it:

```bash
adb=~/AppData/Local/Android/Sdk/platform-tools/adb.exe
$adb install -r build/app/outputs/flutter-apk/app-debug.apk
$adb shell monkey -p com.saferide.falcon -c android.intent.category.LAUNCHER 1
$adb shell screencap /sdcard/s.png && $adb pull /sdcard/s.png shot.png
```

⚠️ Do not pipe `adb exec-out screencap -p > file.png` through PowerShell — its
redirection corrupts binary output. Screencap to the device, then `pull`.
⚠️ A debug build's first launch on an emulator can sit on the native splash for
several seconds (JIT warm-up). Check `adb logcat --pid=$(adb shell pidof <pkg>)`
before assuming a hang.
⚠️ **Judge smoothness on a phone, in a profile or release build — never on
the emulator or a debug build.** This machine's emulator has one 60 Hz mode
and rasterizes every Flutter frame in ~33 ms through gfxstream: a bare
Flutter app with one spinner runs at 23 fps there, SafeRide at ~30.
SafeRide's build phase is ~1 ms a frame (profile build, `FrameTiming`). A
debug build is JIT-compiled and drops frames on any device.
⚠️ Test the **release** APK before shipping — it strips asserts, has its own
manifest merge, and is where the INTERNET and back-dispatcher bugs lived.

---

## 15. Forbidden

Screens nobody asked for · features the spec does not describe, or copy that
promises them · pages or widgets past their size limit · a method
that returns a widget where a widget class belongs · business logic in widgets ·
API calls in the UI · hardcoded strings, colours or sizes · a colour read from
anywhere but `context.appColors` · `'key'.tr()` inside a widget · raw route
paths · left/right instead of start/end · a key added to one translation file
only · duplicate widgets (extend the shared one with a parameter) · unapproved
packages · placeholder files beyond the four named skeletons per feature (§2) ·
a local implementation that pretends to be a server (a local repository is
allowed only when its doc says plainly it is local-only — §16) · unused models ·
inventing an endpoint or faking a response · plaintext passwords in any
storage · architecture built for its own sake.

---

## 16. SafeRide — decisions and batch status

The product spec builds the MVP in batches of up to six screens, each verified
on an emulator in both languages and both themes before the next one starts.

**Batch 1 — done:** splash / startup decision, onboarding ×3, welcome, the
preferences sheet, light / dark / system theme across every existing screen,
ar / en with live switching, persistence.

**Batch 2 — done:** registration and login against local demo accounts with
loading, inline and notification errors and double-submit protection;
sign-out behind a confirmation; a settings screen (account, language,
theme) pushed from home; the notification system, also used for the exit
hint. The forgot-password → OTP → new-password screens were **removed**: no
local MVP can send a reset, and they pretended to. "Continue as a guest" was
removed too — the spec has no guest mode.

**Batch 3 — done:** the home screen per the owner's *Home Screen
Specification*: greeting, Plan a Safe Journey, recent journeys, safety
features (all *Planned*), a three-tab bar (Home, My Journeys, Profile);
plan → review → confirm or cancel → the journey's details with its
status; local, per-account journey history. The placeholder `home`
feature was removed; settings became the Profile tab.

**Batch 4 — done:** My Journeys with status filters and cancel (planned
only, after a confirmation); a departure date and time on every new
journey; editing a planned journey; the Safety tab — Safety Center, Trusted
Contacts (add, edit, delete), Safety Guide, Journey Safety, Emergency
Information; Profile with edit profile, Language & appearance and About.

**Batch 5 — done (integration, reliability, QA):** an audit of every
flow; a fresh-install end-to-end run on the emulator (onboarding →
register → plan / edit / cancel → contacts → sign-out → a second account →
login → restart) in both languages, both themes, System and 2× text; and
the fixes it found — phone and email fields reading `…966+` and then
placing their hint, helper and error on the wrong side in Arabic; login
without a visible back control; a link coloured with a status colour; an
overdue planned journey that could not be edited without a new time;
onboarding and Journey Safety copy that promised a notice or implied
sharing.

**Batch 5, second pass (stabilization before Firebase):** an independent
review of the data, logic and routing code, and three fixes — an edit
screen whose contact could not be read showed an empty form, so Save added
a second contact and Delete reported a deletion that never happened (now
`ContactFormUnreadable`, with a retry); the login's "no account" notice kept
an action bound to the login screen after it closed (now dismissed with
it); Review → Confirm saved a departure that had passed while review stood
open (now re-checked, back to the plan with a notice).

**Batch 6 — done (architecture only, nothing implemented):** Firebase is
the backend. `docs/firebase-architecture.md` holds the design: Auth
(email/password, reset, deletion), Firestore under `users/{uid}` with draft
rules, FCM / Cloud Functions / App Check designed but deferred until a
feature needs them, local-vs-cloud decisions, no separate Node.js backend,
Spark for Batch 7 and Blaze with the first Cloud Function, and the Batch 7
plan.

**Batch 7 — Firebase integration:** application id `com.saferide.falcon`;
Firebase project `saferide-a9d9f` (apps registered with `flutterfire
configure`); Firebase Authentication (register, login, logout, password
reset in the app's language, persistent session, every error mapped);
profiles, journeys and contacts in Firestore behind the existing
interfaces, with the offline copy; Security Rules deployed and tested;
FCM prepared (permission on a Profile tap, the install's id under the
account, foreground / opened / background handling — nothing sends yet);
cloud accounts **start fresh** (the owner's choice): local demo data stays
on phones, unread. Firestore is in **`me-central2` (Dammam)** — a first
rules deploy created it in `nam5` by itself; the owner deleted that empty
database and it was recreated (⚠️ `firebase deploy --only firestore` creates
a missing database in the default region: create it first, with
`--location`). **Verified on the API 36 emulator against the live project:**
initialization; register; a wrong password (one message) and login;
sign-out; the session after a restart; a profile edit; a journey planned,
edited (overdue, departure kept) and cancelled; contacts added; everything
back from the server after the app's data was wiped; a contact added in
airplane mode saved at once and synced on reconnect; a second account sees
nothing of the first; an unauthenticated read refused (`403`); a password
reset (English and Arabic); notification permission and the install's FID
saved under the account. See the open items below for what still waits.

**Batch 8 — the pre-journey safety checklist:** a planned journey starts
(→ **active**, "In progress") only through a nine-item checklist
(`JourneyChecklist` v1: vehicle, fuel or charge, tires and brakes, documents,
fitness, not under the influence, phone battery, trusted contacts,
emergency numbers), every item confirmed by the user on its own screen
(`/journey/start/:id`). The checklist record and the start are one
Firestore batch, and the rules accept the start only with that record
(below). **Verified on the API 36 emulator against the live project:**
items start unchecked and toggle; progress in Arabic-Indic digits; Start
disabled until nine of nine; Not now and back leave the journey planned
with a notice, and a return starts over; an online start; an offline start
(the "saved on this phone" notice, synced on reconnect, accepted by the
rules); both journeys back from the server after the app's data was wiped;
an active journey completed, another cancelled from the list; Arabic RTL
light, English LTR dark, 2× text.

**Batch 9 — route, speed and distance recording:** while a journey is
in progress, `JourneyTracker` records its route with the user's
permission — on the phone first, then to the account in chunks — and the
journey screen shows speed, distance, duration, the current position, GPS
and sync status. **Verified on the API 36 emulator** (simulated fixes,
live project): the explanation before any prompt; Android's location and
notification prompts; the persistent notice; recording with the app in the
background and the screen off; resuming after a force-stop; completing
stops it and clears the notice; recorded offline, completed offline, sent
on reconnect (the phone's copy deleted only once the server confirmed);
the recorded distance read back from the account; Arabic RTL dark, English
LTR light. **Not verified:** a real Android phone (OEM battery killers,
real GPS speed), and anything on iOS (no Mac here).

**Batch 12 — the 15-second safety check:** an eligible potential incident
asks "Are you okay?" over whatever screen is open, with a 15-second
countdown and one "I'm safe" button; no answer marks the incident
escalation-ready for batch 13. Nothing is contacted, called or sent.
**Verified on the API 36 emulator:** a drive then 5 minutes still
produced a medium stop and the Arabic prompt; with the screen locked the
check timed out at its deadline (processed 16 ms after it) and was handed
over; on unlocking, "No answer recorded" was shown and closed.
**Not verified:** "I'm safe" on a device (covered by widget tests), a
process killed during a countdown, a device restart, any iOS device.

**Batch 16 — live location and journey sharing:** a private link shows the
user's location, or a journey in progress, to someone with no account, in the app
or a web viewer. All of it in `docs/location-sharing.md`. The rules and `hosting/`
were deployed on 2026-11-05. **Verified on the API 36 emulator and a
real browser** (debug build of the unmodified app, Firebase emulators with the real
rules, the viewer served locally with the real Hosting headers, live map tiles,
simulated movement): a location share and a journey share started, read signed out
with no owner in the document; the viewer live, stale and ended; offline for 2.5
minutes with no backlog on return; stopping, a journey finishing, sign-out and
account deletion each ending the link; a link opening the app, cold and signed out;
Arabic RTL dark. **Not verified:** a real share on the live project, a real phone,
Android App Links verification, a share past its time on a device, any iOS device.

**Batch 17 — trusted contacts and connections:** two accounts connect through a
private invite (72 hours, once, a 256-bit token) and either can end it. It shares a
name and nothing else; location stays a separate link. All of it, with the rules
and the limits, in `docs/connections.md`. The rules and `hosting/c.html` were deployed on
2026-11-05 and read back identical; if either were missing, the app would say "Not
available yet". **Verified on the API 36 emulator** (debug build of the unmodified app on the
Firebase emulators, real rules, pages served with the real headers, three local
accounts): every path in `docs/connections.md` §9. That run found a bug no fake could:
after an offline attempt, an accept committed and the app said it had not; fixed and
run again the same way. It was also the first run of account deletion against real
rules, in Arabic, and it left nothing behind. **Not verified:** a real invite on the
live project, a real phone, App Links verification, two phones at once, any iOS device.

**Batch 18 — movement detection and false positives:** an audit of detection
and its GPS pipeline, and the fixes it found: a hard stop for a red light, a
crawling queue, a stop at the destination and single GPS glitches no longer ask
"Are you okay?"; weaker evidence waits 45 s; one reading never changes the
engine's mind; a glitch after standing still no longer adds phantom distance; a
provider hiccup no longer ends the recording; "I'm safe" stands until the
vehicle moves. All of it, with thresholds before and after, in
`docs/detection.md`; 23 scenarios replayed through `GpsScript`. **Verified on
the API 36 emulator** (simulated GPS with speed; details in `docs/detection.md`
§8). **Not verified:** a real phone, a real vehicle, any iOS device. Nothing is
deployed and nothing new is stored.

**Batch 19 — the safety escalation workflow:** an unanswered check is kept as
an open escalation until the user says "I'm okay" or the journey ends; the
prompt's follow-up, a note on the journey screen and the notification offer
"I'm okay" and **Get help** — emergency numbers for the chosen country, sharing
by the user's choice, and the user's people, each a tap of their own. Nothing is
called, sent or shared; `AppFeatures.contactAlerts` stays off.
`docs/escalation.md` §11. **Verified on the API 36 emulator** (debug build on
the Firebase emulators, a real safety check from simulated GPS with speed, a
test contact's made-up number): the follow-up in the foreground; Get help with
Saudi Arabia's numbers, Call opening the dialer with nothing placed; "I'm okay"
from the note; the background notification replaced at the deadline, opening
the follow-up, cleared by "I'm okay"; a journey completed with one open, which
closed it. That run found one bug (an escalation shown through its
notification was never marked seen), fixed and checked again the same way.
**Not verified:** a real phone, a lock screen, any iOS device.

**Batch 20 — emergency-service integration:** one emergency directory for
Emergency information and Get help, ordered by what happened, a regional
number first and named, a missing service said; the numbers re-checked on
2026-11-08 (Saudi 911 now structurally regional, three dead source links
replaced, nothing added or removed); every Call through one `CallLauncher`
(prepared number, one launch at a time — which fixed saved numbers typed with
spaces); "Where you are" (current or last known, age, accuracy, the journey in
progress, never sent); "Which service?" and "On the call". `docs/emergency.md`.
**Verified on the API 36 emulator** (debug build on the Firebase emulators,
simulated GPS): the Saudi directory and its sources; location not allowed,
then a reading turning from current to last known; the directory after a cold
start in airplane mode; Get help after a real unanswered check. No emergency
number was dialled. **Not verified:** a real phone, a real call to anything,
any iOS device.

**Batch 21 — calling and texting trusted contacts:** Call and Message for
numbers the user saved, on Get help and the Trusted Contacts list; both open
the user's own app (`tel:`, `sms:`) through the one `CallLauncher`, and the
user places the call or sends the text. Get help's text is "I may need
assistance…" in the app's language, editable, with no location; the list's
opens empty. Connected accounts stay name-only: a connection shares no phone
number, and the copy says so. No backend, rules or collection changed.
`docs/emergency.md` §10. **Verified on the API 36 emulator** (debug build on
the Firebase emulators, made-up test numbers): the list's Call and Message,
Message opening Google Messages to the number with an empty box, a number too
long to dial shown as unusable; Get help's Message after a real unanswered
check. Nothing was sent or dialled. **Not verified:** a real phone, other
messaging apps, any iOS device.

**Batch 15 — interactive maps:** places picked on a map (search, current
location, tap, drag), a route preview, and a live map of the journey in
progress, in both themes and languages. All of it in `docs/maps.md`.
**Verified on the API 36 emulator** (release build, a temporary probe screen
since removed, simulated movement, live providers): tiles, the tuned dark
style, Arabic street names, the route preview, the live map, a dark-to-light
switch mid-journey, search and pin in Arabic, and recording carrying on in
airplane mode. The rules were deployed on 2026-11-04 and read back identical.
**Verified signed in** (debug build of the unmodified app on the Firebase
emulators, real rules, live map providers, simulated movement): register, search,
map tap, route preview, saving with coordinates, the checklist, recording, the
live map, completing, route chunks, and a journey with no coordinates edited,
started and mapped. That run found two bugs, fixed and checked again the same way:
"Use my location" returned a finished journey's last position, and a finished
journey's map said 0.00 km. **Not verified:** the flow on the live project; a real
drive; any iOS device; a mid-range phone's frame rate.

**Batch 14 — final audit and stabilization:** three independent reviews and
fixes with regression tests; account deletion; data retention; and the
owner's decision to **stay on Spark**, so contact alerts are off and the app
says nobody was alerted. Everything is in `docs/PRODUCTION_READINESS.md`.
**Not verified on a device:** any of it — account deletion has only run
against fakes.

**Batch 13 — safety notifications and trusted-contact alerts:** the safety
check as a local notification with "I'm safe"; the backend and the client for
alerting contacts over FCM. Batch 14 turned the alerts off (above). The design
and limits are `docs/escalation.md`. **Tested:** the backend on the emulator (real Admin SDK, fake
provider), the rules on the emulator. **Verified on the API 36 emulator**
(release build, a temporary probe screen since removed, Arabic): the
notification's channel importance, countdown, deadline timeout and text;
"I'm safe" with the app alive; "I'm safe" with the process killed, which
Android restarted for the tap and the next launch read. **Not verified:** the
whole flow on a device (no deployed backend, and no test sign-in), any real
push, any iOS device or the `AppDelegate` change, a real phone, a lock screen.

**Batch 11 — potential-incident detection:** the tracker's own fixes feed a
detection engine that notices a sudden deceleration that lasts, a long
stop after moving, and tracking that stops (with its cause); events are
kept on the phone with a lifecycle for the next batch's safety check, and
a calm, dismissible note shows medium/high movement events on the
journey screen. Nothing is sent, called or escalated. Batch 9's tracker
now takes a fix every 2 s with no distance filter, so standing still is
no longer mistaken for losing the signal. **Verified on the API 36
emulator** (simulated fixes): recording stays "Recording" while still;
a drive then 5 minutes still produced one medium prolonged-stop event and
the Arabic note; dismissing closed it; completing the journey stopped
everything. **Not verified:** real driving, real decelerations, any iOS
device. The thresholds are engineering starting points, not validated
accident detection.

**Batch 10 — country selection and emergency numbers:** the user chooses
the country they are in (Profile, or the emergency screen); the emergency
screen shows that country's numbers from a bundled, validated dataset —
Egypt, Saudi Arabia, the UAE, Kuwait, Qatar, Bahrain and Oman, each number
checked against an official source on 2026-11-03 — with a warning, an
explanation per service, sources and the check date; Call opens the phone
app and says only that. **Verified on the API 36 emulator:** the prompt
when no country is chosen; the picker (flags, both names); Saudi Arabia's
six numbers and 911's regions; Call opened the phone app with 911 ready
(no call was placed); a cold start with the network off kept the country
and the numbers, and a change offline; the Profile row; Kuwait's shared
112 in Arabic RTL, dark; after the rules were deployed, a choice made
while they still refused it was sent and confirmed on the next visit to
Profile.

Decisions (change them here when they change):

- **Startup.** `StartupCubit` decides: onboarding not finished → onboarding
  (auth is not even asked); else `AuthRepository.hasSession()` with an
  `AppDurations.startupTimeout` (8 s) → home or welcome; an error or a timeout
  → `StartupFailed`, which the splash shows with a retry. The splash leaves at
  the later of the logo's entrance (`splashIntro`, skipped under reduced
  motion) and the decision — there is no fixed delay.
- **Preferences.** The onboarding flag and theme mode are in `AppPreferences`
  (shared_preferences, keys `prefs.onboardingCompleted` / `prefs.themeMode`);
  the language is easy_localization's own `locale` key. `PreferencesCubit` is
  an app-wide lazy singleton provided above `MaterialApp` — the one cubit that
  is not a per-screen factory. Onboarding completion is written **before**
  navigating to welcome. Logging out must clear the session only, never these.
- **Auth is Firebase Authentication** (email + password). `AuthRepository`
  is the seam; `FirebaseAuthRepository` implements it and `SessionReader`
  (`id` = the Firebase uid). Passwords never reach SafeRide's storage.
  Emails are trimmed and lower-cased. The profile is `users/{uid}`
  (`fullName`, `phone`, `locale`, `country`, `updatedAt` — no email, no
  password); a
  copy of the name in the Auth display name rebuilds a profile whose first
  write was lost. **Wrong email and wrong password are one error**
  (`invalidCredentials`, under the password field) — Firebase's
  email-enumeration protection answers both alike, and the app never says
  which emails have accounts; the password-reset screen says the same words
  either way. Network, too-many-attempts, disabled and unknown failures are
  notifications. The phone number is never called verified. `hasSession()`
  answers from Firebase's restored session, offline too — "cannot reach the
  server" is never "signed out".
- **Sign-out** (profile, after `showAppConfirmDialog`) first removes this
  install's push record (`DeviceRegistration.unregister`), then signs out of
  Firebase — the onboarding flag, language and theme stay (tested). It
  `go`es to welcome with an info notice.
- **Notifications** (`core/notifications/`): pages call
  `sl<AppNotifier>().show(AppNotification.error(...))` with translated
  strings; `NotificationHost` in `MaterialApp.builder` draws one card at the
  top, under the status bar — clear of the keyboard and the bottom buttons.
  One at a time, newest wins; the same message (`id`) refreshes instead of
  stacking. Success / info leave after `noticeShort` (4 s), warning / error
  after `noticeLong` (8 s), offline stays; with TalkBack nothing leaves on its
  own. The card is a live region read status word first, with its own close
  button node. Field errors, loading and confirmations are **not**
  notifications. ⚠️ While shown it covers the top of the screen (welcome's
  preferences pill, a back tile; at 2× text the long reset notice covers the
  login fields) — it is dismissible and short-lived. No screenshot of the
  reference notification was supplied; the card follows the spec's written
  description (rounded outline, icon, heading, message, close).
- **Profile lives in the authentication feature** (the account is its
  concern; language and theme are `core/` `PreferencesChoices`). It is the
  fourth tab; Home's avatar opens it. Edit profile changes the name and the
  optional phone; the email is how the user signs in and cannot change in
  the app. Language & appearance is its own screen, and a language chosen
  there is also kept as the profile's `locale` (for anything the server
  will write). **About** says where the information is kept and what this
  version does not do (including deleting the account from the app); there is **no
  privacy policy or terms page** — none has been written, and a placeholder
  would pretend. Move Profile to a feature of its own when it gains
  settings that are not the account's.
- **Journeys are per account and honest.** `FirestoreJourneyRepository`
  keeps them at `users/{uid}/journeys`, one live query on the newest 200
  shared by every screen. Sign-out keeps them, as it keeps the account.
  `origin` and `destination` are always the user's own words; a place picked
  on the map adds optional coordinates, and typing over it removes them.
  Status is
  **planned → active → completed**, or **planned / active → cancelled**,
  set only by the user; completing and cancelling ask first. **Active
  means "the user started it"** ("In progress" / «جارية»): its route is
  recorded with permission, no one sees it unless the user shares it, and
  no one is alerted, and every screen around it says so; a planned journey is never shown as
  active, even after its departure time. `startedAt` is
  the server's time of the start (absent until then; hidden while a start
  made offline waits to sync).
  Every planning screen says SafeRide does not track journeys. Nothing is
  stored before Confirm. `departsAt` (UTC) is required and must not be in
  the past when chosen (the rules require it on every journey; the local
  pre-batch-4 records that lacked it did not move to the cloud). Only a planned journey can be
  edited (`alreadyStarted` once started, `notPlanned` once closed); every
  change stamps `updatedAt`. An edit
  keeps the stored departure valid even once it has passed, so a place can
  be fixed without inventing a new time; a newly picked time must be ahead.
- **The pre-journey checklist** is required for every journey, once:
  each journey has its own record at
  `users/{uid}/journeys/{id}/checklists/preJourney` (`journeyId`, `uid`,
  `version`, `items`, `complete: true`, `completedAt` — server time),
  written in the **same batch** as planned → active and never changed, so
  a journey is never active without it and never has a checklist without
  starting. The screen always opens unconfirmed (no answers carried over
  from another journey or an earlier visit); `JourneyStartCubit` starts
  once (taps while saving are ignored); the repository checks the set is
  exactly the version's items (`checklistIncomplete`), and the rules check
  it again. **Versioned:** a released version's items never change; a new
  requirement is a new version, added to `JourneyChecklist.versions`, the
  translation files (`journeys.checklist.v<n>.*`, old keys kept) and the
  rules' `confirmsVersion`. **Consistency:** online, "Journey started"
  shows only once the server confirmed the batch; offline (no answer within
  `syncWait`) the batch is in the phone's queue and the notice says it
  will sync — if the rules later refused it, Firestore would roll the
  cache back and the journey would show planned again. SafeRide checks
  none of the items: they are the user's own confirmations, and the copy
  says so ("No one is told and no one watches it").
- **Route recording** (`JourneyTracker`, one app-wide service — the spec
  asked for a dedicated one; it outlives screens).
  - *Only an active journey*, one at a time, one recording per journey (a
    second start joins it). It starts when the journey screen opens an
    active journey and location is allowed — never asking; the prompt
    comes only from the card's "Allow location" tap, after the card says
    why. It stops when the journey is completed or cancelled (it follows
    the journeys' live query, so from any screen or phone) and pauses on
    sign-out. It never changes a journey's status.
  - *Permission:* precise location while in use. No "always" / background
    permission on either platform. Approximate-only, refused-for-good and
    services-off each get their own explanation and the settings button;
    the card looks again when the app resumes.
  - *Which fixes count* (`RouteFilter`): accuracy ≤ 50 m, not 0,0 or out of
    range, not older than 30 s or than the last point, at least 5 m from
    it, and under 70 m/s from it — **measured from when a fix last agreed
    with that point** (`agreedAt`), so a glitch after standing still cannot
    claim the whole wait as travel time. Three agreeing jumps in a row are
    real (out of a car park): a new segment, nothing counted across. A
    rejected fix adds nothing but still tells a weak signal (> 25 m) from
    none (no fix for 20 s). A late or repeated fix never moves the shown
    position or speed back. A location-provider error that is not a refusal
    is retried (5 s, doubling to a minute), never reported as "permission
    removed".
  - *Speed* is the phone's own reading only (never derived from positions),
    dropped when its error is > 3 m/s, smoothed (EMA 0.4), < 0.5 m/s shown
    as 0; "Now" within 10 s of a fix, else "Last known", else "Not
    available". Whole km/h.
  - *Distance:* haversine between consecutive trusted points of one
    segment. A segment ends when no fix arrives for 2 minutes (or the app
    was closed); no distance is counted across the gap, so the figure is
    a lower bound. GPS error inflates distance slightly at walking pace;
    the 5 m minimum limits it.
  - *Storage:* each trusted point is appended to the app's private files
    (`tracks/<uid>/<journeyId>.points`, flushed; a torn last line is
    skipped) with a session file beside it; one account never reads
    another's. The account gets the points in **chunks of 100**
    (`route/00000`, `00001`, …) with a `tracking/summary` (distance, count,
    first/last time, recording) — every 2 minutes, when a chunk fills, and
    on stop. A chunk is rewritten whole, so a retry never duplicates;
    offline it waits in Firestore's queue and counts once the server has
    it. The phone's copy is deleted when the journey ended and the account
    has everything. Cost: about 2 writes per 2 minutes of journey.
  - *Recovery:* signed-in screens start with `JourneysCubit`, which calls
    `recover()`: an interrupted recording of a still-active journey
    resumes (new segment); recordings of journeys that ended meanwhile
    are finished and sent.
  - *Background:* Android — geolocator's foreground service with the
    persistent notice "SafeRide is recording your journey"; swiping the
    app away ends the Flutter engine and the recording with it, until the
    app opens again. iOS — `UIBackgroundModes: location`,
    `allowBackgroundLocationUpdates`, the blue indicator, no automatic
    pause; iOS may still suspend or end the app, and nothing is promised
    beyond what the system allows.
  - *Fixes:* every 2 s, no distance filter (`GeolocatorLocationSource`):
    a distance filter stops fixes while still, and "still" must be told
    from "no signal". A fix that adds no point saves the session at most
    every 30 s.
  - *Not here:* calling or alerting anyone. Sharing only reads the tracker.
- **Potential-incident detection** (batches 11 and 18; `docs/detection.md`,
  which has every threshold, before and after) — *unusual movement, never
  "an accident".*
  - *Wiring:* `JourneyTracker` hands every fix, tick, interruption, start,
    end and sign-out to one `TrackingObserver`, the `IncidentMonitor` — no
    second location subscription. The monitor runs one
    `IncidentDetectionEngine` (pure, its clock passed in) for the journey
    being recorded; a new journey always gets a fresh engine.
  - *Scenarios* (thresholds in `IncidentDetectionConfig`, each with its
    reasoning; starting points, not validated values): **sudden
    deceleration** — two trusted speed readings ≤ 4 s apart going from
    ≥ 30 km/h to ≤ 5 km/h at ≥ 4 m/s², positions consistent with the
    speeds, then staying put — within 15 m, no crawling, no driving on —
    reported at 15 s when the evidence is high, else at 45 s (a hard stop
    for a red light shows the same drop; the light turns green); a minute
    with no fix drops it; **prolonged stop** — after the journey set off
    (≥ 200 m away or driving, two fixes in a row), within 30 m (or 2×
    accuracy) at ≤ 3.6 km/h for 5 minutes, restarted by any 60 s gap in
    fixes, left after two fixes in a row beyond 50 m; **tracking
    interrupted** — permission removed, services off (immediately),
    no usable fix for 60 s (signal lost), a 30 s gap between ticks (app
    suspended), or resumed after the app was closed — always low
    confidence, never an incident of movement.
  - *Trusted data:* speed only from fixes ≤ 20 m with a speed error ≤ 2 m/s
    (or none reported; 0 or less counts as none); positions ≤ 25 m; fixes
    older than 10 s, repeated or out of order ignored. **One reading never
    changes the engine's mind:** setting off, leaving a stop, moving away or
    crawling during a drop's wait all need two fixes in a row
    (`agreeingFixes`).
  - *Confidence* (`IncidentConfidenceRules`, pure, one test per condition):
    deceleration — high needs ≥ 7 m/s², two driving readings before,
    accuracy ≤ 10 m, both speed errors reported and ≤ 1 m/s, and ≥ 5 fixes
    ≤ 6 s apart while staying put; medium ≥ 5.5 m/s², driving before,
    accuracy ≤ 15 m, still 45 s with no gap over 30 s; else low. Stop — low
    with accuracy over 15 m, a gap over 30 s, two creeps forward (a queue),
    or within 150 m of the planned destination (arrived); else high when it
    began within 60 s of a **medium or high** deceleration; else medium. A
    threshold crossed alone is never high.
  - *Lifecycle:* detected → resolved (movement resumed, tracking
    restored, journey ended) · dismissed (the user's "I'm fine") ·
    superseded (a newer event of the same family — movement or
    interruption — replaces it, `supersededBy`). One condition is never
    stored twice; at most one open event per family per journey. **An
    answer stands:** after "I'm fine" or "I'm safe" about a place, nothing
    new is raised there until the vehicle has moved on
    (`IncidentMonitor._answeredHere`, `engine.lastMovingAt`). After a
    restart a new engine needs the journey to set off before a stop counts,
    so a vehicle still parked is never asked about twice. The tracker tells
    the monitor the journey's planned destination (`TrackingObserver.started`).
  - *Storage:* local only (`incidents/<uid>.json`, atomic, newest 100 per
    account) — no Firestore writes; location rounded to 4 decimals
    (~11 m). Survives a restart; the engine's in-memory state does not
    (a stop restarts its count).
  - *UI:* `JourneyIncident` shows a medium/high open movement event on
    the active journey's screen, on the info colour, saying nothing was
    sent, with "I'm fine, dismiss". Low events and interruptions are kept,
    not shown (a firm brake before a red light can make a low one). No
    notification, sound or vibration.
  - *Limits:* GPS sees a stop's consequences, not an impact; one fix every
    2 s can miss a short event; an emulator reports speed 0. Android: the
    detection runs only while the app process lives (the foreground
    service keeps it alive; swiping the app away ends it). iOS: may
    suspend the app, and may deliver few fixes while still.
- **The safety check** (batch 12, `SafetyCheckService`, one app-wide).
  - *Eligible* (`SafetyCheckEligibility`): an incident still `detected`, a
    sudden deceleration or prolonged stop (never a tracking
    interruption), medium or high confidence, noticed within 2 minutes;
    and, checked by the service, no check ever made for that incident,
    none pending for the account, the journey still active. The incident
    becomes `awaitingConfirmation` (the detection no longer resolves or
    replaces it). One check at a time; the next eligible event waits.
  - *Countdown:* the check stores `startedAt` and `deadline` (+15 s). The
    time left is always `deadline − now` — the prompt redraws every
    250 ms from it, and one timer (injected; fake in tests) is armed for
    the deadline. `recover()` runs at app start and on every return to
    the foreground: an overdue pending check times out then
    (`timedOutAt` = the deadline, `timeoutProcessedAt` = when noticed); a
    running one is shown with the time it has left. A rebuild never
    restarts it.
  - *State machine* (`SafetyCheckStatusX.canMoveTo`): pending →
    confirmedSafe | timedOut | cancelled; timedOut → escalationReady.
    Every change runs in one queue, re-reads the stored check, and is
    refused if not allowed — so expiry is processed once, "I'm safe" at
    or after the deadline is too late, and a second tap does nothing.
  - *Outcomes:* "I'm safe" → check `confirmedSafe` (`confirmedAt`),
    incident `dismissed` / `confirmedSafe`. No answer → `timedOut`, then
    `escalationReady`; incident `escalationReady` (details kept) — **no
    answer, not an accident**. The journey ending or the account signing
    out → `cancelled` (incident `resolved` / `checkCancelled`), never
    escalated.
  - *Storage:* `safety_checks/<uid>.json`, atomic, 50 per account; no
    location in a check. An unanswered one is reported (below).
  - *Prompt:* `SafetyCheckHost` in `MaterialApp.builder` lays it over every
    route: "Are you okay?", the seconds in a ring (Arabic plurals for the
    screen reader), "I'm safe", and what no answer does. After a timeout:
    "No answer recorded", what became of the alert (`EscalationStatus`),
    I'm okay, Get help, Close. Scrolls at large text.
  - *Off screen:* a notification instead of the prompt, never both.
  - *Limits:* Android: the timer runs while the recording's foreground service keeps the process
    alive; if the process is killed, the deadline is processed on the next
    launch. iOS: the app may be suspended — the timer may not fire until
    it returns, when `recover()` processes the deadline; nothing runs in a
    terminated app on either platform, and a device restart is the same
    as a terminated app.
- **After no answer** (batch 19; `docs/escalation.md` §11). The escalation is
  the check in `escalationReady`, on the phone — no new store, nothing sent.
  The lifecycle the spec names (`SafetyStage`: incidentDetected … resolved)
  is **derived** from the record, never stored. The record keeps a copy of
  the event (type, confidence, time; no location), `presentedAt` (first on
  screen, foreground only) and `resolvedAt` + `resolution` (`userSafe`: a late
  "I'm okay"; `journeyEnded`). Both are idempotent, a resolved record never
  reopens, and `EscalationSync` skips it. `recover()` closes records whose
  journey ended, then shows an unseen open one — the one on hand first.
  Other features see it only through `core/safety/EscalationGate`
  (`SafetyCheckService` implements it): an id, a journey and times.
  **Get help** (`/safety/help`) is the user's own taps: the chosen country's
  numbers (none guessed), a link to the existing sharing screen (nothing
  starts there by itself), connected people by name, saved numbers by name
  with Call (numbers stay in the cubit). It never says anyone was told:
  `help_copy_test` reads both translation files. The "No answer recorded"
  notification replaces "Are you okay?" (same id) and opens the follow-up;
  a refused post is not believed shown.
- **Safety never pretends.** Trusted Contacts, Safety Resources and sharing are
  live on Home and in the Safety tab. Saved numbers are stored at `users/{uid}/contacts` (at most 20, sorted
  by name, a number listed once — compared by its digits, also stored as
  `phoneDigits`); SafeRide never verifies their numbers, and only a contact
  who accepted an invite can receive an alert. It says so. The guide is general advice in the translation files (offline).
  No notification icon on Home until a notification destination exists.
- **The country the user is in** (`core/country/`) is what the emergency
  numbers follow — chosen by the user, never guessed from the SIM, the
  language or the location (no reliable offline way exists, and a wrong
  guess shows wrong numbers). One value, labelled "Country you're in", not
  a nationality or home country. Kept on the phone (`AppPreferences`,
  read at once, offline) and in the profile (`users/{uid}.country`).
  **Conflicts:** a choice made on this phone and not yet confirmed by the
  server wins and is sent; otherwise the account's value wins (a new phone
  takes it after sign-in); an account with none is given the phone's.
  `CountryCubit` reconciles whenever a screen that shows it opens. Adding
  a country: a line in `Countries.supported` and an entry in the dataset.
- **Emergency numbers** live in `assets/data/emergency_services.json` —
  data, not code, and never in a widget. Per country: the numbers, the
  service types each answers (one number may answer several: Kuwait 112,
  Qatar and Bahrain 999, Oman 9999 are one tile "Emergency"), a check
  date, the sources (publisher in both languages, https) and notes in both
  languages. `verification` is `official` (a national government source
  states it) or `secondary` (only foreign travel advice — shown, marked
  "confirm locally"); **unverified numbers are not in the file**.
  `EmergencyDataSource` validates every entry and leaves a broken country
  out whole (the screen then says it has no checked numbers) — never half
  shown; its test fails the build on any invalid entry. A number may be
  `"scope": "regional"` and must then name its regions in a note; the
  directory lists it first and `numberFor` never returns it — SafeRide never
  picks a regional number from GPS. The dataset ships
  with the app: offline from the first launch, no remote update (one would
  be another `EmergencyRepository`, validated the same way before it
  replaces anything). Re-checked 2026-11-08 (`docs/emergency.md` §2) — SA:
  911 (regional: Riyadh, Makkah, Madinah, Eastern Province), 997, 999
  (outside the 911 regions, per the Interior Ministry), 998 (outside the 911
  regions), 993, 996 (CST numbering plan; Okaz and Asharq Al-Awsat reporting
  the ministry and Civil Defense); AE: 999, 998, 997 (u.ae, every
  emirate); KW: 112 (MOI); QA: 999 (MOI, Hamad Medical Corporation); BH:
  999, 199 traffic accidents (bahrain.bh); OM: 9999 (ROP, gov.om, CDAA);
  EG: 122, 123, 180, 01221110000 traffic accidents (MOI, SIS). Left out as
  unverified or disputed: Egypt's 112, Saudi Arabia's 112, the UAE's 112,
  Bahrain's 112, Oman's old 999.
- **Calling** (`CallLauncher` → `PhoneDialer`): every Call in the app goes
  through the one app-wide `CallLauncher`. `DialNumber.prepare` takes out
  spaces, dashes, dots and brackets, then the number must be 2–15 digits
  (optional `+`); one launch at a time, and a second tap within
  `AppDurations.dialCooldown` of the phone app opening is ignored (null).
  The phone must say something can dial (`canLaunchUrl`), then `tel:` opens
  the phone app with it ready. The outcome is `opened`, `invalidNumber`,
  `noDialer` or `failed`, each with its own notice — "opened" says the user
  presses call and that SafeRide cannot see whether the call was made. There
  is no outcome past "opened": SafeRide reads no phone state. Nothing dials by
  itself; nothing claims a call happened; nothing about a call is stored; no
  `CALL_PHONE`. Tests never open a real dialer or use a real emergency number.
- **Texting** (batch 21; `CallLauncher.message` → `MessageComposer`): only a
  number the user saved (`ContactReach` says before the tap whether it can be
  used); the same preparation and the same one-launch guard as calling. Get
  help pre-fills "I may need assistance. Please contact me as soon as
  possible." (`safety.reach.body`), the Trusted Contacts list opens empty; the
  user edits and sends. **No location is ever put in a text** — sharing
  stays Batch 16's link, sent by the user. No SMS permission, nothing stored,
  and no outcome says sent or delivered. **A connection never exposes a
  number**: connected people are listed by name only, with no Call or
  Message.
- **Where you are** (batch 20, `EmergencyLocationCard`): the core
  `EmergencyPositionReader`, implemented over `JourneyTracker` — the one GPS
  source. On open only what is known (the recording's newest fix); a new
  reading only on a tap; never a permission prompt. "Current" within 20 s,
  then "Last known" with its age, a warning past 5 minutes; accuracy said
  (rough past 100 m); 0,0 never shown; Latin digits, left to right, with Copy.
  It says the location is not sent to emergency services and they cannot see
  it. Nothing is sent, stored or logged.
- **Greeting.** "Good morning / afternoon / evening, {first name}" (05–12,
  12–17, else). `SessionUser.firstName` is the first word, joined to the
  next when it is half a name («عبد», «أبو», Abd/Abdel/Abdul/Abdal/Abu).
- **Brand.** "SafeRide" is not translated. As a Latin run inside Arabic it is
  safe as a standalone word; do not put neutral punctuation right after it in
  Arabic copy. The logo mark is single-colour and recoloured with `onPrimary`
  on a `primary → secondary` tile; neither is ever mirrored. The tile's
  gradient runs `Alignment.topLeft → bottomRight` — a deliberate physical
  alignment (the other is Latin input fields, §8), because a directional one
  flips the brand in Arabic.
- **Motion** (§7). Restrained by default. The rings around the logo on
  welcome and onboarding loop because the owner asked for them to move all
  the time — a breath and a turning orbit: calm, and nothing that reads as
  tracking. The splash intro is 600 ms from the launch hand-off and is never
  lengthened; entrances settle by 780 ms.
- **Small teal text** uses `accentText` (light `#0F766E`, dark `#5EEAD4`), not
  `secondary`: the brand teal is under 4.5:1 on the light background.
  `secondary` stays for rules, icons and fills.
- **Directional glyphs.** `assets/icons` glyphs are drawn for LTR
  (`chevron_left.svg` is a `<`); `DirectionalSvg` mirrors them in RTL. Check a
  new asset's geometry, not its name.
- **Illustrations.** There are no illustration assets yet. Onboarding draws its
  art from Material Rounded icons (one consistent, Apache-licensed family that
  ships with Flutter and recolours with the theme) inside
  `OnboardingIllustration`. Replace it with real art when a designer supplies
  it; the step data (`OnboardingStep`) is the only thing that changes.
- **Honest copy.** Route recording is described as what it is — the user's own
  record, kept in their account, only during a journey they started and with
  their permission, seen by no one unless they share it. Sharing is voluntary,
  and is never described as emergency protection, as monitored, or as reaching a
  person: "reaching your link" means the server has it, and nothing can tell
  whether anyone looked. A link is a bearer link, never called impossible to
  find, and stopping one never claims to erase what was seen. Nothing may
  describe monitoring or emergency response as working until it is built.
  Trusted-contact alerts are
  described as an attempt that can fail; "accepted" is the provider's word
  and **nothing says delivered**. Preferences are per device,
  not per account, so no copy may say an account keeps them. Detection
  copy says SafeRide "noticed unusual movement" — never that it detected
  or confirmed an accident.
- **Firestore behaviour.** Every write waits `AppDurations.syncWait` (4 s)
  for the server, then counts as saved on the phone and syncing later
  (`settle`) — offline a write's future would never complete. A pending
  server timestamp reads as now. One live query per collection
  (`UserCollection`) serves every screen and every reload from memory;
  only changed documents are billed. Last write wins per document; the one
  invariant that matters (a closed journey never reopens) is the rules'.
  The Firestore cache is not cleared on sign-out: the app only queries the
  signed-in uid's paths (Batch 6 doc §6.2).
- **Security Rules** (`firestore.rules`): only the owner reaches
  `users/{uid}/**`; fields listed, typed and sized; `createdAt`/`updatedAt`
  must be the server's time; a journey is edited only while planned,
  starts (planned → active, `startedAt` = server time) only when the same
  write creates its complete checklist record (`getAfter`), and closing
  changes only its status; a checklist record is created only with that
  start, for a known version with all its items, and never updated; route
  chunks (`route/{00000…}`, 1–100 points, first and last point checked —
  rules cannot loop) and the `tracking/summary` exist only under a journey
  that has started (`get()`), are the owner's alone, and may arrive after
  it ended; contacts need digits-only `phoneDigits`;
  `devices` hold `fid`, `platform`, `updatedAt`; the profile's optional
  `country` is two capital letters (a new country needs no new rule);
  everything else is closed.
  Deploy: `firebase deploy --only firestore:rules`.
- **Push (FCM) carries one thing: a trusted contact's alert.** Permission is
  asked from the Profile row or with location; the install registers (`register()`) only while signed in
  and allowed, and its FID goes to `users/{uid}/devices/{installId}`
  (`installId` is a random per-install id in `AppPreferences`). Foreground
  messages show as the app's notification card; an opened message goes to
  an allowlisted route once a signed-in tab is on screen; the background
  handler does nothing. The backend addresses installs by FID.
- **Sharing** (batch 16; `docs/location-sharing.md`). A public document at
  `shares/{token}` (256-bit token, read by `get` only, until `expiresAt` by the
  server's clock) with **no owner in it**: rules cannot hide a field. Ownership is
  `users/{uid}/shares/{token}`, made only in the write that creates the public
  document, so a leaked token cannot be claimed. Stopping deletes both.
  **`JourneyTracker` stays the one source of GPS:** `LocationSharing` reads
  `trustedFixes`; with no journey, `watch()` holds the same subscription open,
  recording nothing. Detection never hears of it, and `AppFeatures.contactAlerts`
  stays off. **Publishing uses transactions, never plain writes:** a queued offline
  write takes the server's time when it lands, so an old position would look live.
  At most a position per 15 s after 10 m, a confirmation per minute standing still,
  the route once a minute. One share per account; a journey's share ends with the
  journey. The app reads a new share back as a signed-out recipient, and fetches the
  viewer, before showing a link, so undeployed rules or Hosting give "not available
  yet", never a dead link. **A new field on `shares/{token}` is public:** nothing
  that identifies the owner may go there. **A new collection under `users/{uid}`**
  still needs its line in `FirestoreAccountData`, and `shares` has one.
  (`connections` is erased by `FirestoreConnectionRepository.erase`, which runs first:
  ending one writes to the other person's record.)
- **Connections** (batch 17; `docs/connections.md`). An invite at
  `connectionInvites/{token}`; one record per side at
  `users/{uid}/connections/{contactUid}`. **The rules are the boundary:** accepting
  writes the invite and both records in one transaction, each checking the others
  (`getAfter`, `existsAfter`), and is the one time an account writes into another's
  path; the other side can otherwise only end a record. **A connection grants
  nothing:** `ConnectionAccess` refuses location, journeys and routes whatever is
  stored, `permissions` must be `{safetyAlerts: false}`, and no rule reads a
  connection. A new feature asks `ConnectionAccess`; a new permission changes the
  rules too. **Security-sensitive steps are write-only transactions:** never a plain
  write (it queues offline), and no read inside (the SDK retries, and a failure
  thrown there can lose to the plugin's). Read from the server first, and let
  `_commit` ask whether a failed write landed. Only `permission-denied` and
  `not-found` are refusals: offline, a transaction reports `unknown`. Ending a
  connection never touches a Batch 16 link, nor the reverse. Saved numbers
  (`contacts`) are separate and unchanged, and Batch 13's code invites stay behind
  `AppFeatures.contactAlerts`.
- **Maps** (batch 15; `docs/maps.md`). OpenFreeMap tiles, Photon search, OSRM
  routing: none needs a key, all behind interfaces, base URLs by
  `--dart-define`. **`JourneyTracker` stays the one source of GPS:** the live
  map reads its snapshots, summary and points and joins its recording; "Use my
  location" is the recording's fix while running and under 20 s old, else one
  reading, on a tap; an older fix is never offered. A distance nothing recorded
  is hidden, never 0. Remaining distance and arrival show only within 150 m of the
  planned route, labelled estimates. North stays up (no rotation). ⚠️ The
  OSRM demo is "non-commercial": replace it before a commercial release.
  ⚠️ Each map style needs its own `id`, or light mode draws dark
  tiles. A map screen's `Stack` needs `StackFit.expand`, or it collapses to
  its one unpositioned child.
- **No alerts on Spark** (`AppFeatures.contactAlerts`, off, the owner's
  decision). Off: `EscalationSync` sends nothing, unanswered checks stay on
  the phone as `escalationReady`, invites and "Alerts for you" are hidden, the
  second channel is not made, and `EscalationCubit` says `serviceUnavailable`
  whatever else it hears — nobody was alerted, with no retry, because nothing
  could change. Copy is written for this state; turning the flag on means
  changing it (`docs/escalation.md` §10). On, a backend silent for 2 minutes
  reads as unavailable too, with Try again.
- **Account deletion** (Profile, `AuthRepository.deleteAccount`): password
  first (Firebase wants a recent sign-in, and it stops a borrowed phone), then
  each `AccountData` in order — push, this phone's journey data (recording and
  check stopped first), Firestore, the country — then the profile, then the
  sign-in. Reads go to the server. **A new collection under `users/{uid}` needs
  a line in `FirestoreAccountData`.** A failure says it may be half done;
  running again finishes it. Nothing is kept for audit (no need identified).
- **Retention:** finished incidents and checks leave the phone after 90 days;
  unanswered ones only under the caps. Routes stay in the account until it is
  deleted. Sign-out keeps this phone's per-account files, for unsent routes.
- **Failed listeners** (`UserCollection`) wait `retryAfter` (30 s) before a new
  one: lists reload on every failure, and a refusal would otherwise loop. A
  document that cannot be read is skipped.
- **Trusted-contact alerts, when a backend exists** (batch 13;
  `docs/escalation.md`).
  - *The phone claims, the server decides.* `EscalationSync` writes the
    check and its incident in one batch; `onSafetyCheckCreated` re-checks
    everything (`eligibility.ts`). Backend-only collections, closed to every
    client write: `escalations` (+ `attempts`), `contactLinks`,
    `receivedAlerts`, `contactInvites`.
  - *Idempotency:* the escalation's id is the safety check's id, created in
    a transaction; each send is claimed first. At most one alert per journey
    per 30 minutes, three per account per 24 hours; a request over 24 hours
    late, or for a journey no longer active, is rejected.
  - *FCM only,* and only to a contact who accepted a one-time invite code.
    No SMS or email (no provider, no credentials). Matching accounts by
    phone number is not done: no number is verified.
  - *No location goes to anyone,* and none is uploaded with a request.
  - *Status:* the app shows only the backend's record; `accepted` is never
    "delivered". Offline it says contacts can't be alerted yet.
  - *No retraction yet:* a user who answers late cannot tell contacts they
    are fine. Raised for review, as is the 15-second window now that the
    outcome reaches other people.
- **Open items:** `docs/PRODUCTION_READINESS.md` §10. In short: real-phone tests, a privacy policy, a release
  keystore, the Play declarations, app icons, bundling Cairo, App Check, and iOS
  (needs a Mac).