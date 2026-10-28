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
| 2 | Application id `com.example.basecode` | `android/app/build.gradle.kts` (`namespace`, `applicationId`), iOS bundle id in Xcode | **open** — needs the owner's reverse-domain id |
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
  details (planned / completed / cancelled; a planned one can be edited).
  Accounts, journeys and contacts are **local to the phone** (§16).
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
- **No network backend**, and no networking package installed — §9 is the
  recipe for when SafeRide gets an API (or Firebase, behind the same
  repository interfaces).
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

A repository that the app must be able to swap (local today, Firebase or an
API later) is an `abstract interface class <Feature>Repository` with the
implementation beside it — `AuthRepository` + `LocalAuthRepository`. The
service locator chooses the implementation; nothing else names it.

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
  di/              # service_locator.dart — get_it wiring, the one cross-feature import point
  notifications/   # AppNotification + AppNotifier + NotificationHost — the toast system
  extensions/      # context, figma units, locale digits
  platform/        # Dart ends of the native glue in MainActivity (LaunchHandoff)
  preferences/     # AppPreferences + PreferencesCubit — app-wide settings
  router/          # AppRoutes, AppRouter, AppPages, AppTabShell, AppBackButtonDispatcher
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

`core/di/service_locator.dart` is the one exception: it is the wiring point.

---

## 3. File map

```
lib/
  main.dart                         # portrait lock, edge-to-edge, EasyLocalization, DI, App
  core/
    constants/app_constants.dart    # AppDesign · AppSpacing · AppRadius · AppDurations
    constants/app_motion.dart       # AppCurves (the five curves) · AppMotion (offsets, distances)
    constants/app_locales.dart
    constants/app_assets.dart
    di/service_locator.dart         # get_it: prefs, secure storage, repositories, cubits
    extensions/context_extensions.dart   # context.texts / colors / appColors / isRtl / isDark /
                                         #   reduceMotion / directionSign
    extensions/figma_extensions.dart     # .fx / .fsp
    notifications/app_notification.dart  # kind, title, message, action, duration, id
    notifications/app_notifier.dart      # the one channel: show / dismiss (one at a time)
    notifications/notification_host.dart # draws it over every route (MaterialApp.builder)
    notifications/notification_card.dart · notification_parts.dart   # the card
    extensions/locale_numbers.dart       # Arabic-Indic digits, dates, the pickers' locale
    platform/launch_handoff.dart         # waits for MainActivity to remove the system splash
    preferences/app_preferences.dart     # onboarding flag + theme mode (shared_preferences)
    preferences/preferences_cubit.dart · preferences_state.dart   # app-wide singleton
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
    shared_widgets/app_text_field.dart   # label + validated field + password eye; phone and
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
    shared_widgets/title_bar.dart             # back tile + screen title (`back: false` on a tab)
    shared_widgets/app_empty_state.dart       # icon, title, body, optional action
    shared_widgets/info_note.dart · section_heading.dart
    shared_widgets/link_tile.dart             # icon tile + title + body + chevron
    shared_widgets/point_list.dart            # a titled card of points (guide, About)
    theme/app_colors.dart · app_text_theme.dart · app_theme.dart · system_bars.dart
    validation/validators.dart
  features/
    authentication/
      data/models/user_model.dart            # freezed: name, email, phone?, createdAt
      data/models/local_account_model.dart   # freezed: user + salt + hash + iterations
      data/models/auth_failure.dart          # the one error the repository throws
      data/repository/auth_repository.dart   # interface — the auth seam
      data/repository/local_auth_repository.dart   # demo accounts in secure storage (local only);
                                                   #   also the app's SessionReader
      data/repository/password_hasher.dart   # PBKDF2-HMAC-SHA256 on a background isolate
      logic/cubit/auth_cubit.dart            # login / register submission
      logic/cubit/account_cubit.dart         # profile: current user, edit, sign-out
      logic/cubit/startup_cubit.dart         # where the app opens
      logic/states/auth_state.dart · account_state.dart · startup_state.dart
      presentation/
        pages/    splash · onboarding · welcome · login · register · profile (a tab) ·
                  edit_profile · settings (language & appearance) · about
        widgets/  splash_{branding,logo,failure,status_slot} · window_anchor ·
                  onboarding_{slide,top_bar,footer,illustration,badges,scene,orbit,
                  eyebrow,dots} · page_parallax · halo_ring{,s} · welcome_{hero,top_bar} ·
                  auth_{header,link_button,notices} ·
                  login_{fields,footer} · register_{fields,footer} · profile_fields ·
                  settings_account_card · password_strength_bar
    journeys/                              # home is the journey dashboard, so it lives here
      data/models/journey_model.dart         # freezed: id, origin, destination, departsAt?, status, dates
      data/models/journey_draft.dart         # places + departure between plan and review (not stored)
      data/models/journey_failure.dart       # the one error the repository throws
      data/repository/journey_repository.dart       # interface — the journeys seam
      data/repository/local_journey_repository.dart # per account, secure storage (local only)
      logic/cubit/journeys_cubit.dart        # the account's journeys + first name (home, list, plan)
      logic/cubit/plan_journey_cubit.dart    # review's Confirm
      logic/cubit/journey_cubit.dart         # one journey: load, complete, cancel, edit
      logic/states/journeys_state.dart · plan_journey_state.dart · journey_state.dart
      presentation/
        pages/    home · my_journeys · plan_journey · review_journey · journey · edit_journey
        widgets/  home_{header,safety_section} · plan_journey_card · safety_feature_tile ·
                  journey_{list,tile,tile_body,status_chip,route_card,facts,actions,
                  labels,notices,form,filter_bar} · journeys_content · place_chips ·
                  departure_field
    safety/
      data/models/trusted_contact_model.dart # freezed: id, fullName, phone, relationship?, createdAt
      data/models/contact_failure.dart       # the one error the repository throws
      data/models/emergency_number.dart      # Saudi Arabia's numbers, with sources and the date checked
      data/repository/trusted_contacts_repository.dart        # interface — the contacts seam
      data/repository/local_trusted_contacts_repository.dart  # per account, secure storage (local only)
      logic/cubit/contacts_cubit.dart        # the list
      logic/cubit/contact_form_cubit.dart    # add, load, save, delete one
      logic/states/contacts_state.dart · contact_form_state.dart
      presentation/
        pages/    safety_center (a tab) · trusted_contacts · contact_form (add + edit) ·
                  safety_guide · journey_safety · emergency_info
        widgets/  contact_{tile,fields,form_actions} · emergency_number_tile · safety_notices
assets/
  translations/{ar,en}.json
  icons/                            # SVGs (recoloured at runtime with a ColorFilter)
  images/logo_mark.svg              # the brand mark, single colour
test/                               # mirrors lib/: core/{constants,di,notifications,platform,
                                    # preferences,router,session,shared_widgets,theme},
                                    # features/{authentication,journeys,safety}/{data,
                                    # logic,presentation}
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
a footer, a form section. Over the target today: `contact_form_page` (177),
`login_page` (154) and `edit_journey_page` (153) — all under the ceiling;
split them when they next grow.

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
| `flutter_secure_storage` | demo accounts, the session, journeys, trusted contacts — **never** `shared_preferences` for these |
| `crypto` | SHA-256 / HMAC for the salted PBKDF2 password hash (the Dart team's package) |
| `freezed_annotation`, `json_annotation` + dev `freezed`, `json_serializable`, `build_runner` | the generated models (`UserModel`, `LocalAccountModel`, `JourneyModel`, `TrustedContactModel`) |
| `url_launcher` | Emergency information's Call: opens the phone app with the number filled in (`tel:`); the user presses call. Nothing dials on its own |
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
first use.

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

Today `_up` sends login and register to **welcome**; My Journeys, Safety,
Profile and plan to **home**; review to plan; a journey and its edit screen
to My Journeys; the contacts list, the guide, journey safety and emergency
information to Safety; add / edit contact to the contacts list; edit
profile, settings and About to Profile. Welcome never leads back
to onboarding: once onboarding is finished it is reached only by a fresh
install.

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
`/safety/journeys`, `/safety/emergency`) and the profile screens
(`/profile/edit`, `/profile/settings`, `/profile/about`) are top-level, so
they open over the tab bar. Confirming a plan does `goNamed(home)` then
`pushNamed(journey)`: plan and review leave the stack, and back from the
details is home. `AppRouter.create()` builds a fresh router; tests use it.

### Pages

Every `GoRoute` uses a `pageBuilder` returning `AppPages.stage` (splash,
onboarding, welcome, the four tab roots — and the shell itself) or
`AppPages.task` (everything pushed); `app_pages_test` fails on a route with a
plain `builder` and counts the routes (22). The
dispatcher's "up" `go` passes `extra: AppPages.up`, which makes a task page
arrive with the stage fade, so going back never looks like going forward.
`MaterialApp.builder` paints a root `ColoredBox(appColors.background)` under
every route, so a fade-through never shows the window's own colour.

---

## 12. Android release gotchas

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

A test that builds journey screens uses the real `AppRouter.create()` and
a `LocalJourneyRepository` over the secure-storage mock with a fake
`SessionReader`; the safety screens do the same with
`LocalTrustedContactsRepository`. Every `SessionReader` fake needs a
`changes` stream (`const Stream<void>.empty()` when nothing renames).
`service_locator_test` runs the app's real wiring (`setupServiceLocator`
over the storage mocks) across two accounts: each sees only its own
journeys and contacts, by list and by id, and preferences survive both
sign-outs. A test that builds login, register or the profile screens registers their cubit in
`sl` (`AuthCubit` / `AccountCubit`) over a fake `AuthRepository`; a fake that
implements only what it needs extends `Fake`. `LocalAuthRepository` is tested
over `FlutterSecureStorage.setMockInitialValues` with a few-round
`PasswordHasher`. A test that shows a notification lets its timer run out
before it ends, or the test fails on a pending timer.

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
$adb shell monkey -p com.example.basecode -c android.intent.category.LAUNCHER 1
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

**Batch 6 — not defined yet.** Candidates: the §0 open items, and the first
feature that needs a backend (accounts, password reset, journey sharing)
once one is chosen.

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
- **Auth is local and not production-secure.** `AuthRepository` is the seam a
  Firebase or API implementation replaces (one line in the service locator);
  it throws only `AuthFailure`. `LocalAuthRepository` keeps demo accounts in
  `flutter_secure_storage`: `auth.accounts` (email → user + salt + PBKDF2
  hash + rounds) and `auth.session` (the signed-in email). The password is
  never stored — `PasswordHasher` derives a 32-byte PBKDF2-HMAC-SHA256 key,
  30 000 rounds with a 16-byte random salt, on a background isolate (about
  0.2 s on a laptop). That is demo-grade: far below server practice, with no
  lockout, no email verification and no recovery. Emails are trimmed and
  lower-cased. A session naming a missing account is no session. The UI says
  "saved on this phone only" on register, in its success notice and in
  profile, and never calls the phone number verified.
- **Sign-out** (profile, after `showAppConfirmDialog`) deletes
  `auth.session` only — the accounts, onboarding flag, language and theme stay
  (tested). It `go`es to welcome with an info notice.
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
  optional phone; the email is the account's key on the phone and cannot
  change. Language & appearance is its own screen. **About** says what the
  app keeps on the phone and what this version does not do; there is **no
  privacy policy or terms page** — none has been written, and a placeholder
  would pretend. Move Profile to a feature of its own when it gains
  settings that are not the account's.
- **Journeys are local and honest.** `LocalJourneyRepository` keeps each
  account's journeys in `flutter_secure_storage` under `journeys.<email>`
  (where someone travels is sensitive), newest first, capped at 200.
  Sign-out keeps them, as it keeps the account. Places are the user's own
  words — no geocoding, maps, location or routes. Status is
  **planned → completed or cancelled**, set only by the user, each behind a
  confirmation; there is deliberately no "in progress" — on a safety app a
  status that suggests someone watches a trip is false reassurance; a
  planned journey is never shown as active, even after its departure time.
  Every planning screen says SafeRide does not track journeys. Nothing is
  stored before Confirm. `departsAt` (UTC) is required for new journeys and
  must not be in the past; it is nullable only so journeys stored before
  batch 4 still load («Departure not set»). Only a planned journey can be
  edited (`notPlanned` otherwise); every change stamps `updatedAt`. An edit
  keeps the stored departure valid even once it has passed, so a place can
  be fixed without inventing a new time; a newly picked time must be ahead.
- **Safety is local and never pretends.** Trusted Contacts and Safety
  Resources are live on Home and in the Safety tab; Journey Sharing stays a
  *Planned* tile (it needs a backend). Contacts are stored per account under
  `contacts.<email>` (at most 20, sorted by name, a number listed once —
  compared by its digits); SafeRide never verifies or messages them, and
  says so. The guide is general advice in the translation files (offline).
  **Emergency numbers** are Saudi Arabia's, checked on 2026-10-28: 911
  (unified, Ministry of Interior — Riyadh, Makkah, Madinah, Eastern
  Province), 999 police, 997 ambulance, 998 civil defense, 993 traffic, 996
  road security; the sources (MOI / SPA, stc, OSAC) are listed on the screen
  and in `EmergencyNumber`. 112 is left out — sources disagree. Call opens
  the phone app with the number filled in; nothing dials, shares a location
  or alerts anyone automatically. No notification icon on Home until a
  notification destination exists.
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
- **Honest copy.** Journey sharing is labelled *coming soon* on onboarding,
  with no promise to tell anyone when it arrives (the app cannot); nothing
  in the app may describe live location, emergency response, journey
  tracking or sharing as working — or imply that someone else learns where
  the user is — until it is built. Preferences are per device,
  not per account, so no copy may say an account keeps them.
- **Open product decisions:** the Android application id / iOS bundle id
  (§0 step 2); launcher PNGs for API 24–25 and the iOS icon; bundling Cairo as
  an asset (google_fonts downloads it on first launch, so an offline first
  launch shows the fallback font); a real password reset, which needs a
  backend (until then "Forgot your password?" shows an info notice saying
  reset is not available).
