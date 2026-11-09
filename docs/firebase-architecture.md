# SafeRide — Firebase architecture (Batch 6)

The plan for moving SafeRide from local-only storage to Firebase. **Nothing
here is implemented yet**: Batch 6 is analysis; Batch 7 implements the
"mandatory" part of §11. Facts about Firebase were checked on 2026-10-31
against the official pricing page, the Firestore locations page and the
Firebase Apple SDK's `Package.swift`; package versions against pub.dev the
same day. Re-check anything time-sensitive before relying on it.

`CLAUDE.md` stays the source of truth for the app's rules. Where this
document proposes changing one of them, it says so, and the change lands in
`CLAUDE.md` when Batch 7 makes it.

> **Batch 7 built this, with these deliberate differences** (CLAUDE.md §16
> has the details):
> - **FCM was prepared in Batch 7**, at the owner's request, instead of
>   waiting for the first feature that sends a push. `firebase_messaging` 17
>   replaced tokens with `register()` / `onRegistered` (the Firebase
>   Installation ID), so device records hold `fid`, not `token`.
> - **Journeys load the newest 200** on one live query, as the local version
>   did, instead of pages of 50 — no UI change was needed. Revisit paging if
>   read costs grow.
> - **`clearPersistence()` is not called on sign-out**: it needs the
>   Firestore instance stopped (`terminate()`), and the app only ever queries
>   the signed-in uid's paths anyway.
> - **Account deletion is not built yet** (still required before a store
>   release), and `locale` on the profile is optional.
> - **The Firestore database is in `me-central2` (Dammam)**, as planned — after
>   a first rules deploy had created it in the default `nam5` region and the
>   owner deleted it. Create the database before deploying rules.
> - **FID registration needs an opt-in** (Android manifest
>   `firebase_messaging_installation_id_enabled`, iOS
>   `FirebaseMessagingInstallationIdEnabled`).
>
> **Batch 8 added** the journey status `active` (with a server-set
> `startedAt`) and one document per started journey at
> `users/{uid}/journeys/{id}/checklists/preJourney` — the pre-journey safety
> checklist, written in the same batch as the start and required by the
> rules. §5 below predates both; CLAUDE.md §16 is current.
>
> **Batch 9 added** a journey's recorded route under the journey:
> `route/{chunk}` (up to 100 points each, zero-padded ids) and
> `tracking/summary` (distance, point count, times, recording). The phone
> records each point locally first and sends chunks every 2 minutes, when a
> chunk fills, and when the journey ends — never one write per fix. Rules:
> owner only, only under a started journey.
>
> **Batch 10 added** an optional `country` (ISO 3166-1 alpha-2) to the
> profile at `users/{uid}`: the country the user says they are in, which the
> emergency numbers follow. The numbers themselves are bundled with the app
> (`assets/data/emergency_services.json`), not stored in Firestore.
>
> **Batch 11 added nothing to Firestore** on purpose: potential-incident
> events stay on the phone (`incidents/<uid>.json`) until a later batch
> needs them in the account.
>
> **Batch 12 added nothing to Firestore either**: safety checks ("Are you
> okay?", 15 s) are kept on the phone (`safety_checks/<uid>.json`). Batch
> 13 decides what of an escalation-ready check reaches the account or
> anyone else.

---

> **Batches 13–14:** Cloud Functions and the collections they own are written
> and emulator-tested, and **stay undeployed: the project remains on Spark by
> the owner's decision**, so where this document assumes a later move to Blaze,
> that move is not planned. The flow, setup and limits are in
> [`escalation.md`](escalation.md), which replaces §7.3 here; the state of the
> project is in [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md). Account
> deletion runs from the phone (`FirestoreAccountData`), not a function.
> Batch 15 adds optional place fields to journeys: see [`maps.md`](maps.md).
> Batch 16 adds the first data outside `users/{uid}`: `shares/{token}` is readable
> by whoever holds the token, with no owner in it, and Firebase Hosting serves its
> web viewer. Both stay within Spark, and both were deployed on 2026-11-05: see
> [`location-sharing.md`](location-sharing.md). §5.7's top-level `incidents` was not used: an incident lives at
> `users/{uid}/incidents`.

## 1. Summary — the recommended architecture

- **Firebase Authentication** (email + password) replaces the local demo
  accounts. **Cloud Firestore** replaces local storage for the profile,
  journeys and trusted contacts. Both run on the **free Spark plan**.
- **No separate Node.js backend.** When the app needs trusted server code
  (pushes, emergency escalation, sharing), it is **Cloud Functions (2nd
  gen, TypeScript)** in a `functions/` folder of this repository. That is
  the point where the project moves to **Blaze**.
- **FCM, Cloud Functions and App Check are designed here but not built in
  Batch 7**: no current feature sends a notification or needs server code,
  and the project's rule is that a package arrives with its first use.
- **The app's architecture does not change.** The three repository
  interfaces and `SessionReader` are already the seams; Batch 7 adds a
  Firebase implementation behind each and switches the service locator.
  Cubits, states, pages and routing keep their shape.
- **Every user's data lives under `users/{uid}`** and only that user can
  read or write it — enforced by Firestore Security Rules, not by the app.
- **Theme, language choice and the onboarding flag stay on the device**
  (an existing decision: preferences are per device, not per account).
- **No location is collected today, and none is planned for Batch 7.** The
  live-location design in §6.3 is for a later sharing feature, and it writes
  one document per share, never a GPS history.

---

## 2. Phase 1 — the existing architecture and where Firebase fits

### 2.1 What is there

| Concern | Today | Firebase fit |
|---|---|---|
| Structure | Feature-first: `authentication`, `journeys`, `safety`, plus `core/` | Unchanged |
| Layers | `data` (models, repositories) · `logic` (cubits, states) · `presentation`. **No domain layer, entities, use cases, data sources or services — on purpose** (CLAUDE.md §2) | Firebase calls live **inside the repository implementations**, which is where the local storage calls live today. No data-source layer is added |
| Models | freezed + json_serializable: `UserModel`, `LocalAccountModel`, `JourneyModel`, `TrustedContactModel`; dates in UTC | Same models; a `Timestamp` ↔ `DateTime` JSON converter; `LocalAccountModel` is deleted |
| Repositories | `abstract interface class` + one implementation each: `AuthRepository`/`LocalAuthRepository`, `JourneyRepository`/`LocalJourneyRepository`, `TrustedContactsRepository`/`LocalTrustedContactsRepository` | One Firebase implementation each, same interface (a few methods added, §3.5) |
| Session | `core/session/SessionReader` (`signedInUser()`, `changes`); the auth repository implements it; `SessionUser.id` is the email | `SessionUser.id` becomes the Firebase **uid** |
| Errors | One failure type per repository (`AuthFailure`, `JourneyFailure`, `ContactFailure`) with codes | Firebase exceptions are mapped to these codes inside the repository; cubits never see a `FirebaseException` |
| Change notification | Each repository has `Stream<void> changes`; list cubits reload on it | Fed by Firestore snapshot listeners |
| State | flutter_bloc cubits (one per screen, factories); Equatable states | Unchanged |
| DI | get_it in `core/di/service_locator.dart`, the one wiring point | Firebase instances registered there; implementations swapped there |
| Routing | go_router, `StatefulShellRoute` (4 tabs), 22 named routes, back dispatcher; the splash decides where the app opens (`StartupCubit` → `AuthRepository.hasSession()`) | `hasSession()` answers from Firebase's persisted session; routes unchanged, one added (§11) |
| Local storage | `flutter_secure_storage`: `auth.accounts`, `auth.session`, `journeys.<email>`, `contacts.<email>`. `shared_preferences`: onboarding flag, theme, locale | Secure-storage keys go away; `shared_preferences` stays |
| Auth | Local PBKDF2-hashed demo accounts (`PasswordHasher`, `crypto`) | Firebase Auth; `PasswordHasher`, `crypto` and `LocalAccountModel` are deleted |

### 2.2 How Firebase enters without breaking the architecture

1. **Behind the existing interfaces.** `FirebaseAuthRepository implements
   AuthRepository, SessionReader`, `FirestoreJourneyRepository implements
   JourneyRepository`, `FirestoreTrustedContactsRepository implements
   TrustedContactsRepository`. The service locator registers these instead
   of the local ones — the "one line per seam" the code was written for.
2. **Firebase types stop at the repository.** No widget, cubit or state
   imports `firebase_auth` or `cloud_firestore`. `core/firebase/` holds the
   only shared Firebase helpers (converters, collection paths).
3. **No new layer.** A "data source" class between repository and Firestore
   would only forward calls; CLAUDE.md §2 forbids layers built for their own
   sake. The repository *is* the adapter.

### 2.3 Inconsistencies found

- **None that block Firebase.** The batch 5 audits fixed the defects; the
  seams are clean (no feature imports another's internals).
- **Two things the interfaces assume that Firebase changes:**
  - **`AuthFailureCode.noAccount` vs `wrongPassword`.** Firebase's
    email-enumeration protection (recommended, and on by default for new
    projects — confirm in the console) answers both with one
    `invalid-credential`. The login screen's two messages merge (§3.4).
  - **"The email is the account's key and does not change."** Still true for
    the UI, but the storage key becomes the uid. No code outside the
    repositories depends on the key, so nothing else changes.
- **About 20 strings say data is "saved on this phone only"** (register,
  profile, About, contacts, journeys). They become false with Firebase and
  must be rewritten in the same change (§11.4) — the honest-copy rule.

---

## 3. Phase 2.1 — Firebase Authentication

### 3.1 Flows

| Flow | Firebase call | Notes |
|---|---|---|
| Register | `createUserWithEmailAndPassword`, then create `users/{uid}` (§5.2) | If the profile write fails, the next app start finds a user without a profile and offers to finish it (the repository writes it again) — never a half-account that cannot sign in |
| Login | `signInWithEmailAndPassword` | Email trimmed + lower-cased first, as today |
| Logout | `signOut()` | Clears the Firebase session only. Onboarding, language and theme stay (an existing rule, tested today) |
| Session persistence | Automatic on Android and iOS (Firebase keeps the session in the platform's secure store) | Nothing for the app to store |
| Auth state | `authStateChanges()` | The repository subscribes once and feeds `changes` |
| Startup decision | First event of `authStateChanges()` (or `currentUser` after `Firebase.initializeApp`) | `StartupCubit` keeps its 8 s timeout and retry; a signed-in user with no network still opens Home from the cache — "cannot reach the server" is **not** "signed out" (CLAUDE.md §9 lesson) |
| Password reset | `sendPasswordResetEmail(email)` after `setLanguageCode(context's language)` | Reset emails in Arabic or English. The screen always says "if an account exists, we've sent a link" — it never confirms an email exists |
| Profile edit | Firestore write to `users/{uid}` | Name and phone stay in Firestore, not in the Auth `displayName` — one source |
| Email change | Not offered (as today) | Later: `verifyBeforeUpdateEmail` |
| Email verification | `sendEmailVerification()` after registering | **Recommended, not blocking** in Batch 7: a profile note "Email not verified — resend". It becomes required before any sharing feature (a contact must be sure who invites them) |
| Account deletion | Re-authenticate → delete the user's documents → delete `users/{uid}` → `user.delete()` | **Mandatory once accounts are online** — Google Play and the App Store both require in-app account deletion for apps that create accounts. Client-side is possible at SafeRide's sizes (≤ 50 loaded journeys per page, ≤ 20 contacts); see §7 for the server-side alternative |

### 3.2 Session in the app

- `hasSession()` = `FirebaseAuth.instance.currentUser != null` after init. It
  answers from the persisted session and does not need the network.
- `signedInUser()` returns `SessionUser(id: uid, fullName: profile.fullName)`
  from the repository's cached profile (one snapshot listener on
  `users/{uid}` while signed in), so the greeting costs no extra reads.
- On sign-out the repository cancels its listeners **before** calling
  `signOut()`. A listener still attached when the user changes would get
  `permission-denied` from the rules.

### 3.3 Interface changes (`AuthRepository`)

```dart
Future<void> sendPasswordReset(String email);         // new
Future<void> deleteAccount({required String password}); // new: re-auths first
// unchanged: hasSession, currentUser, register, login, updateProfile,
//            logout, changes
```

`UserModel.createdAt` reads from the Auth user's `metadata.creationTime`,
so it is not duplicated into Firestore.

### 3.4 Error mapping (`FirebaseAuthException.code` → `AuthFailureCode`)

| Firebase | AuthFailureCode | Shown |
|---|---|---|
| `email-already-in-use` | `emailTaken` (exists) | Under the email field, as today |
| `invalid-credential`, `user-not-found`, `wrong-password` | **`invalidCredentials`** (new; replaces `noAccount` + `wrongPassword`) | Under the password field: "Email or password is incorrect" |
| `invalid-email` | `invalidEmail` (new) | Under the email field (the form already validates; this is the server's word) |
| `weak-password` | `weakPassword` (new) | Under the password field |
| `too-many-requests` | `tooManyRequests` (new) | Notification: "Too many attempts. Try again later." |
| `network-request-failed` | `network` (new) | Notification with retry; offline does **not** mean signed out |
| `requires-recent-login` | `requiresRecentLogin` (new) | Delete-account flow asks for the password again |
| `user-disabled` | `disabled` (new) | Notification |
| anything else | `unknown` (exists) | Notification |

`storage` stays for Firestore write failures of the profile. The login
screen's "No account — create one?" notice goes away with `noAccount`.

### 3.5 Copy and screens this touches

- **Login:** one error under the password field (above). "Forgot your
  password?" opens the reset flow instead of today's "not available" notice.
- **Forgot password:** a new small screen (email field + Send), the one new
  route Batch 7 adds — the spec-backed replacement for the screens removed
  in batch 2, which were removed precisely because nothing could send a
  reset.
- **Profile:** "Saved on this phone only" becomes "Signed in as …"; a
  "Delete account" action at the bottom, behind a confirmation and the
  password.

---

## 4. Phase 2.2 — Cloud Firestore (overview)

The full structure is §5; the rules are §8. What to store:

| Entity | Where | Batch |
|---|---|---|
| User + profile | `users/{uid}` (one document, not two) | 7 |
| Journeys | `users/{uid}/journeys/{journeyId}` | 7 |
| Trusted contacts | `users/{uid}/contacts/{contactId}` | 7 |
| User settings that must follow the account | Fields on `users/{uid}` (`locale` today) | 7 (`locale` only) |
| Device tokens (FCM) | `users/{uid}/devices/{installationId}` | With FCM |
| Notification inbox | `users/{uid}/notifications/{id}` | Only with an in-app inbox |
| Emergency incidents | `incidents/{incidentId}` (top level) | With an SOS feature |
| Live location while sharing | `liveShares/{shareId}` (top level) | With journey sharing |

Settings that stay **device-only**: theme mode, the chosen language (also
mirrored to `users/{uid}.locale` so the server can write notifications in
it), the onboarding flag. Nothing in the app may claim the account keeps
them (existing honest-copy rule).

---

> **Batch 17 changed one assumption here.** Linking two accounts does not need a
> Cloud Function after all: `connectionInvites` and `users/{uid}/connections` do it
> under Security Rules alone, on Spark (`docs/connections.md`). What still needs a
> backend is everything that acts on a link: alerts, and hiding the inviter's id.

## 5. Phase 3 — Firestore database design

**Conventions.** Field names are `camelCase`, matching the Dart models.
Times are Firestore `Timestamp`, written as `FieldValue.serverTimestamp()`
for `createdAt` / `updatedAt` (the rules check them against
`request.time`); `departsAt` is a client time the user chose. Document IDs
are Firestore auto-IDs (`collection.doc().id`), which replaces the local
`_newId`. Enums are lower-case strings. The database is created **once, in
one region, which cannot be changed later** (§9.4).

### 5.1 Relationships

```
users/{uid}                       one per Auth user (uid = Firebase Auth uid)
 ├─ journeys/{journeyId}          owned by uid
 ├─ contacts/{contactId}          owned by uid; a phone number, not an account
 ├─ devices/{installationId}      (with FCM) one per signed-in install
 └─ notifications/{id}            (with an inbox) written by Cloud Functions
incidents/{incidentId}            (with SOS) ownerUid → users/{uid};
                                  journeyId → users/{uid}/journeys/{id}
liveShares/{shareId}              (with sharing) ownerUid, journeyId,
                                  viewerUids written by Cloud Functions
```

Per-user subcollections make ownership structural: a path under
`users/{uid}` is that user's, and the rules check one condition. The two
top-level collections are the ones **other people** may later read
(responders, trusted contacts), which a per-user path cannot express without
collection-group rules.

### 5.2 `users/{uid}` — user and profile (Batch 7)

| Field | Type | Required | Written by | Notes |
|---|---|---|---|---|
| `fullName` | string, 2–200 | yes | owner | Today's name rule |
| `phone` | string, 7–25, or null | no | owner | **Never verified** — as today |
| `locale` | `"ar"` \| `"en"` | yes | owner | Mirrors the device's chosen language for server-written text |
| `updatedAt` | timestamp | yes | owner (server time) | |

**Not stored:** email (it is in Firebase Auth; a copy would drift), creation
time (Auth metadata), password (Auth never exposes it). Only the owner reads
it; there is no public profile. If a sharing feature needs other people to
see a name, it gets a separate, minimal document written by a function,
never this one.

Indexes: none beyond automatic.

### 5.3 `users/{uid}/journeys/{journeyId}` (Batch 7)

| Field | Type | Required | Notes |
|---|---|---|---|
| `origin` | string, 2–120 | yes | The user's own words; no geocoding |
| `destination` | string, 2–120 | yes | |
| `departsAt` | timestamp | yes | Required for every journey in the cloud (no pre-batch-4 records there) |
| `status` | `"planned"` \| `"completed"` \| `"cancelled"` | yes | planned → completed or cancelled; a closed journey never changes |
| `createdAt` | timestamp (server) | yes | Never changes |
| `updatedAt` | timestamp (server) | yes | Every change |

Queries and indexes:

- Home and My Journeys share **one** listener:
  `orderBy('createdAt', descending: true).limit(50)` — a single-field index,
  created automatically. Older journeys load in pages of 50 when scrolled to.
  The status filter stays client-side on the loaded page, so no composite
  index is needed.
- Later, server reminders ("your journey leaves in 30 min") would need a
  **collection-group** composite index on `journeys`: `status ASC,
  departsAt ASC`. Not in Batch 7.

The local cap of 200 goes away; paging replaces it.

### 5.4 `users/{uid}/contacts/{contactId}` (Batch 7)

| Field | Type | Required | Notes |
|---|---|---|---|
| `fullName` | string, 2–200 | yes | |
| `phone` | string, 7–25 | yes | As typed |
| `phoneDigits` | string, digits only, 7–20 | yes | Today's duplicate check compares digits; stored so the check needs no reformatting |
| `relationship` | string, 1–40, or null | no | |
| `createdAt` | timestamp (server) | yes | |
| `updatedAt` | timestamp (server) | yes | |

At most 20 per user: the list is small, so it is read whole (one listener)
and sorted by name on the device — no index. The duplicate-number check
stays on the device: it is a convenience rule, not a security boundary. The
20-contact cap is enforced by the app; rules cannot count documents (a
Cloud Function trigger can, later, if abuse appears).

Later (sharing): `linkedUid` (string, **written only by a Cloud Function**
once the contact accepts an invitation with their own account).

### 5.5 `users/{uid}/devices/{installationId}` (with FCM)

| Field | Type | Notes |
|---|---|---|
| `token` | string | The FCM registration token |
| `platform` | `"android"` \| `"ios"` | |
| `locale` | `"ar"` \| `"en"` | Language for pushes to this device |
| `updatedAt` | timestamp (server) | Tokens older than ~60 days are pruned by a scheduled function |

The document ID is the Firebase Installation ID, so a reinstall replaces its
own document instead of adding one. Deleted on sign-out.

### 5.6 `users/{uid}/notifications/{id}` (only with an in-app inbox)

| Field | Type | Notes |
|---|---|---|
| `type` | string (`"journeyReminder"`, …) | |
| `title`, `body` | string | Already in the user's `locale` |
| `route`, `routeId` | string, string or null | Where a tap leads (an allowlisted route name) |
| `createdAt` | timestamp | |
| `readAt` | timestamp or null | The only field the owner may change |

Written by Cloud Functions only. **Do not create this collection until the
app has an inbox screen**: storing every push would cost a write per push for
nothing anyone reads.

### 5.7 `incidents/{incidentId}` (with an SOS feature — not designed into any screen yet)

| Field | Type | Written by | Notes |
|---|---|---|---|
| `ownerUid` | string | owner, on create | |
| `journeyId` | string or null | owner, on create | |
| `status` | `"open"` \| `"cancelled"` \| `"resolved"` | owner (open → cancelled/resolved), function | |
| `location` | geopoint or null | owner, on create | **One** position at the moment of SOS, never a stream |
| `locationAt` | timestamp or null | owner | |
| `createdAt` | timestamp (server) | owner | |
| `closedAt` | timestamp or null | owner/function | |
| `escalation` | map (`stage`, `notifiedContactIds`, `lastAttemptAt`) | **function only** | |
| `viewerUids` | array of uid (≤ 20) | **function only** | Linked trusted contacts who may read it |

Index: `ownerUid ASC, createdAt DESC` (a user's incident history).

### 5.8 `liveShares/{shareId}` (with journey sharing — later)

| Field | Type | Written by |
|---|---|---|
| `ownerUid` | string | owner |
| `journeyId` | string | owner |
| `viewerUids` | array of uid (≤ 20) | function only |
| `location` | geopoint | owner |
| `accuracyM` | number | owner |
| `updatedAt` | timestamp (server) | owner |
| `expiresAt` | timestamp | owner; a Firestore **TTL policy** deletes the document after it |

One document per share, **overwritten** on each update — never a history.
See §6.3.

---

## 6. Phase 4 — local vs cloud vs memory

### 6.1 Where each piece of data lives

| Data | Device | Firestore | Memory only | Why |
|---|---|---|---|---|
| Auth session | Firebase's own secure store | — | — | Firebase manages it |
| Profile (name, phone) | Firestore offline cache | `users/{uid}` | Cached copy in the auth repository | Follows the account across phones |
| Journeys | Firestore offline cache | `users/{uid}/journeys` | Latest page in the repository | Follows the account |
| Trusted contacts | Firestore offline cache | `users/{uid}/contacts` | Full list in the repository | Follows the account; needed later for escalation |
| Theme mode | `shared_preferences` | — | — | Per device (existing decision) |
| Language | `shared_preferences` (easy_localization) | Mirrored to `users/{uid}.locale` | — | The device decides; the server only reads it |
| Onboarding done | `shared_preferences` | — | — | Per install |
| Form drafts (plan → review) | — | — | `JourneyDraft` in route `extra` | Nothing is stored before Confirm (existing rule) |
| GPS positions | — | Only §6.3's single documents, only while a share or incident is active | Latest position in memory | Location is the most sensitive data the app could hold |
| FCM token | — | `devices/{installationId}` | — | The server needs it to send |
| Emergency numbers, safety guide | Bundled in the app | — | — | Static, must work offline |

### 6.2 Offline, consistency and conflicts

- **Offline cache.** Firestore's persistence is on by default on Android and
  iOS. Screens read from the repository's listener, which serves the cache
  first and the server when it arrives. An app restart without network shows
  the last synced journeys and contacts.
- **Writes offline.** A write is applied to the cache at once and queued.
  ⚠️ **Its `Future` completes only when the server confirms it**, so
  awaiting it offline hangs the button. The repositories await with a short
  timeout (about 3 s); on timeout they return success marked *pending*, and
  the notice says "Saved — it will sync when you're online". A write the
  server later **rejects** (rules) disappears from the cache; the listener's
  next snapshot shows the true state, and the repository reports
  `storage` once. Rules are written so a valid offline write is never
  rejected later — they never compare a client time with the server's
  clock (§8.3).
- **Server timestamps.** Until a write reaches the server, its
  `createdAt`/`updatedAt` read as **null** in snapshots: FlutterFire's
  `snapshots()` has no `ServerTimestampBehavior` option (only `GetOptions`
  for one-off reads does). The timestamp converter reads a pending null as
  the local time of the write, and the repository sorts the (≤ 50) loaded
  journeys on the device, so a new journey still shows first.
- **Conflicts.** One user, one owner per document; edits are rare and small.
  **Last write wins** per document is acceptable. The one invariant that
  matters — a closed journey never reopens — is enforced by the rules, so a
  stale offline edit to a journey completed on another phone is rejected
  instead of reopening it.
- **Transactions** fail offline, so Batch 7 uses none (no operation needs
  one).
- **Network failures** map to `network` codes (§3.4); screens show their
  existing error states with retry. Signed-in users are never sent to
  welcome because the network is down.
- **Sign-out on a shared phone.** `signOut()` does not clear the Firestore
  cache. The app only ever queries the signed-in uid's own paths, so the
  next account on the phone never *sees* the previous one's cached
  journeys — the same isolation today's per-email keys give. For defense in
  depth, sign-out then calls `terminate()` and `clearPersistence()`:
  `clearPersistence()` only works while the Firestore instance is stopped,
  and its Future fails otherwise. Batch 7 must confirm how FlutterFire
  restarts the instance on next use. The docs also note that clearing does
  **not securely erase** the files; disabling persistence entirely is the
  only stronger option, at the cost of offline use.

### 6.3 Location strategy (for a later sharing or SOS feature)

Firebase does not track location, in the foreground or background; the app
would need a location plugin (`geolocator`, already the obvious choice) and
the platform permissions in §10.

- **Default: nothing.** No position is read or stored unless the user starts
  a share or an SOS, and the UI shows that it is on.
- **SOS:** one position written into the incident document at creation;
  optionally refreshed every 2–5 minutes while the incident is open.
- **Live sharing:** the device keeps a position stream in memory
  (`distanceFilter` 50–100 m) and **overwrites one `liveShares/{shareId}`
  document** at most once every 30–60 s, and only after the user moved
  meaningfully. The rules enforce the minimum interval
  (`request.time > resource.data.updatedAt + duration.value(30, 's')`), so
  a bug cannot flood writes. No history is kept; `expiresAt` + a TTL policy
  removes the document when the share ends or is forgotten.
- **Cost of that:** a 45-minute shared trip at one write a minute is ~45
  writes, plus ~45 reads per viewer listening. That is fine on Blaze. On
  Spark's 20K writes/day it caps out around 400 shared trips a day, which is
  another reason sharing arrives with Blaze.

---

## 7. Phase 2.3/2.4 — Cloud Messaging and Cloud Functions

### 7.1 FCM design (build with the first feature that sends a push)

1. **Permission** — asked **in context**, when the user turns on something
   that notifies (e.g. journey reminders), never at first launch. Android 13+
   needs the runtime `POST_NOTIFICATIONS` permission; iOS shows its own
   prompt. A refusal is respected; the setting explains how to enable it
   later.
2. **Token** — after permission: `getToken()`, written to
   `users/{uid}/devices/{installationId}`; `onTokenRefresh` rewrites it. On
   sign-out: delete the device document, then `deleteToken()`.
3. **Foreground** — Android does not show notification messages while the
   app is open. Show them through the app's existing `AppNotifier` toast
   (an info notice with the tap action), which avoids adding
   `flutter_local_notifications` until a feature needs system-tray
   notifications in the foreground. iOS: `setForegroundNotificationPresentationOptions`.
4. **Background / terminated** — notification payloads are shown by the
   system. A top-level `@pragma('vm:entry-point')` background handler is
   registered only if data-only messages are used. It cannot touch UI and
   should not touch Firestore.
5. **Opened from a notification** — `getInitialMessage()` (cold start) and
   `onMessageOpenedApp` (from background). The payload carries `route` (a
   route **name** from an allowlist) and an optional id. Navigation waits
   until the startup decision is made and the user is signed in; an unknown
   route opens Home. Android notification channels (`journey_reminders`,
   `safety_alerts`) are declared once, with a default channel in the
   manifest.
6. **Sending** is server-side only (Admin SDK in Cloud Functions). The app
   never holds a server key.

### 7.2 What needs trusted server code (Cloud Functions)

| Operation | Why it cannot be client-side | When |
|---|---|---|
| Sending any push | Needs the Admin SDK / server credentials | With the first push feature |
| Emergency escalation (SOS → contacts) | Must run even if the phone dies; must rate-limit; may use paid SMS with secret API keys | With SOS |
| SMS or WhatsApp to contacts without the app | Provider keys live in **Secret Manager**, never in the app | With SOS / sharing |
| Linking a trusted contact to an account (invitations) | Writes `linkedUid` / `viewerUids`, which grant access to another user's data | With sharing |
| Scheduled journey reminders | No device is guaranteed to be awake | Optional |
| Pruning stale FCM tokens | Scheduled | With FCM |
| Full account cleanup on Auth deletion | Guarantees no orphaned data if the client stops midway | Optional (see below) |

**Safe in the app** (guarded by rules): creating, editing and closing your
own journeys; your own contacts; your profile; requesting a password reset
(Firebase Auth does it); signing in and out; your own device token; account
deletion at today's data sizes.

**Account deletion, two ways.** Client-side (re-authenticate → batch-delete
the user's journeys, contacts and devices → delete `users/{uid}` → delete the
Auth user) works on Spark and fits SafeRide's sizes. A Cloud Function on Auth
user deletion (or the official "Delete User Data" extension) is sturdier if
the client is killed midway, and it needs Blaze. **Batch 7: client-side**,
ordered so the Auth user is deleted last.

### 7.3 Future emergency escalation — requirements to plan for

- **An incident is created by the user** (an SOS button), never inferred
  from silence until a check-in feature exists and the user has agreed to it.
- **A function triggers on the incident** — notify linked contacts by push,
  others by SMS (only contacts who were told and agreed — Saudi PDPL
  consent; §12). Then escalate in stages if nobody acknowledges.
- **Idempotent and rate-limited:** one active incident per user, at most N
  notifications per contact per hour, every attempt recorded on the
  incident.
- **SafeRide never calls emergency services itself.** The Emergency
  Information screen already opens the dialer for the user. Automatic calls
  are not possible from a function, and implying them would break the
  honest-copy rule.
- **Copy stays honest:** the app does not say anyone is notified until the
  feature exists and a delivery has been confirmed.

### 7.4 App Check

- **Include it, in monitoring mode first.** It stops other apps and scripts
  from using the project's Firestore with SafeRide's (public) API key — the
  main threat to a free-tier quota.
- **Providers:** Android → Play Integrity (default quota 10,000 requests a
  day, raisable once the project is linked in the Play Console); iOS → App
  Attest with DeviceCheck fallback; debug builds → the debug provider with
  tokens registered in the console (never shipped in a release).
- **Enforce only after the app is distributed through Google Play** (or a
  Play testing track). Play Integrity does not recognise an APK installed by
  hand, so enforcing earlier would lock out the sideloaded release builds
  SafeRide is tested with today.
- **Timing:** optional in Batch 7 (monitor only); enforce for Firestore and
  Functions before a public release.

---

## 8. Phase 5 — security architecture

### 8.1 Principles

- **The rules are the security boundary.** Flutter validation is for
  feedback; every rule the server must hold is restated in
  `firestore.rules`.
- **Default deny.** Anything not matched is refused.
- **Ownership comes from the path** (`users/{uid}` with `request.auth.uid ==
  uid`) or from `ownerUid == request.auth.uid` at the top level.
- **Fields that grant access to someone else** (`viewerUids`, `linkedUid`,
  `escalation`) are **writable only by Cloud Functions** (the Admin SDK
  bypasses rules; clients cannot write them).
- **Schema checks:** `keys().hasOnly(...)` lists, types, lengths; timestamps
  equal `request.time` where the server sets them.
- **No secrets in the app.** `firebase_options.dart` and the platform config
  files hold the project's *identifiers* (not secrets). The Android and iOS
  API keys are restricted in Google Cloud to the app's package name / bundle
  id and to the Firebase APIs it uses. Server keys and SMS credentials live
  only in Secret Manager.

### 8.2 Rules (draft for Batch 7 — not yet compiled; must pass the emulator tests before deploy)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function isOwner(uid) { return signedIn() && request.auth.uid == uid; }
    function text(v, min, max) {
      return v is string && v.size() >= min && v.size() <= max;
    }
    function optionalText(d, k, min, max) {
      return !(k in d) || d[k] == null || text(d[k], min, max);
    }
    function changedOnly(keys) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(keys);
    }

    match /users/{uid} {
      function validProfile(d) {
        return d.keys().hasOnly(['fullName', 'phone', 'locale', 'updatedAt'])
          && d.keys().hasAll(['fullName', 'locale', 'updatedAt'])
          && text(d.fullName, 2, 200)
          && optionalText(d, 'phone', 7, 25)
          && d.locale in ['ar', 'en']
          && d.updatedAt == request.time;
      }
      allow read: if isOwner(uid);
      allow create, update: if isOwner(uid) && validProfile(request.resource.data);
      allow delete: if isOwner(uid);

      match /journeys/{journeyId} {
        function validJourney(d) {
          return d.keys().hasOnly(['origin', 'destination', 'departsAt',
                                   'status', 'createdAt', 'updatedAt'])
            && d.keys().hasAll(['origin', 'destination', 'departsAt',
                                'status', 'createdAt', 'updatedAt'])
            && text(d.origin, 2, 120) && text(d.destination, 2, 120)
            && d.departsAt is timestamp
            && d.status in ['planned', 'completed', 'cancelled']
            && d.updatedAt == request.time;
        }
        allow read: if isOwner(uid);
        allow create: if isOwner(uid)
          && validJourney(request.resource.data)
          && request.resource.data.status == 'planned'
          && request.resource.data.createdAt == request.time;
        // Only a planned journey changes. Editing keeps it planned; closing
        // changes nothing but the status. A closed journey never reopens.
        allow update: if isOwner(uid)
          && resource.data.status == 'planned'
          && validJourney(request.resource.data)
          && request.resource.data.createdAt == resource.data.createdAt
          && (request.resource.data.status == 'planned'
              || changedOnly(['status', 'updatedAt']));
        // The UI never deletes a journey; account deletion does.
        allow delete: if isOwner(uid);
      }

      match /contacts/{contactId} {
        function validContact(d) {
          return d.keys().hasOnly(['fullName', 'phone', 'phoneDigits',
                                   'relationship', 'createdAt', 'updatedAt'])
            && d.keys().hasAll(['fullName', 'phone', 'phoneDigits',
                                'createdAt', 'updatedAt'])
            && text(d.fullName, 2, 200)
            && text(d.phone, 7, 25)
            && d.phoneDigits is string && d.phoneDigits.matches('^[0-9]{7,20}$')
            && optionalText(d, 'relationship', 1, 40)
            && d.updatedAt == request.time;
        }
        allow read, delete: if isOwner(uid);
        allow create: if isOwner(uid)
          && validContact(request.resource.data)
          && request.resource.data.createdAt == request.time;
        allow update: if isOwner(uid)
          && validContact(request.resource.data)
          && request.resource.data.createdAt == resource.data.createdAt;
      }

      // With FCM:
      match /devices/{installationId} {
        allow read, delete: if isOwner(uid);
        allow create, update: if isOwner(uid)
          && request.resource.data.keys().hasOnly(['token', 'platform', 'locale', 'updatedAt'])
          && text(request.resource.data.token, 20, 4096)
          && request.resource.data.platform in ['android', 'ios']
          && request.resource.data.locale in ['ar', 'en']
          && request.resource.data.updatedAt == request.time;
      }

      // With an inbox: written by Cloud Functions only.
      match /notifications/{id} {
        allow read: if isOwner(uid);
        allow update: if isOwner(uid) && changedOnly(['readAt'])
          && request.resource.data.readAt == request.time;
        allow create, delete: if false;
      }
    }

    // With SOS. Escalation and viewer fields are written by functions only.
    match /incidents/{incidentId} {
      allow read: if signedIn()
        && (resource.data.ownerUid == request.auth.uid
            || request.auth.uid in resource.data.get('viewerUids', []));
      allow create: if signedIn()
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.keys().hasOnly(['ownerUid', 'journeyId',
             'status', 'location', 'locationAt', 'createdAt'])
        && request.resource.data.status == 'open'
        && request.resource.data.createdAt == request.time;
      allow update: if signedIn()
        && resource.data.ownerUid == request.auth.uid
        && resource.data.status == 'open'
        && changedOnly(['status', 'closedAt'])
        && request.resource.data.status in ['cancelled', 'resolved']
        && request.resource.data.closedAt == request.time;
      allow delete: if false;
    }

    // With sharing: one overwritten document per share, rate-limited.
    match /liveShares/{shareId} {
      allow read: if signedIn()
        && (resource.data.ownerUid == request.auth.uid
            || request.auth.uid in resource.data.get('viewerUids', []));
      allow create: if signedIn()
        && request.resource.data.ownerUid == request.auth.uid
        && !('viewerUids' in request.resource.data)
        && request.resource.data.updatedAt == request.time;
      allow update: if signedIn()
        && resource.data.ownerUid == request.auth.uid
        && changedOnly(['location', 'accuracyM', 'updatedAt', 'expiresAt'])
        && request.resource.data.updatedAt == request.time
        && request.time > resource.data.updatedAt + duration.value(30, 's');
      allow delete: if signedIn() && resource.data.ownerUid == request.auth.uid;
    }

    match /{document=**} { allow read, write: if false; }
  }
}
```

Only the `users/**` part ships in Batch 7. The `devices`, `notifications`,
`incidents` and `liveShares` blocks ship with their features; until then the
final deny covers them.

### 8.3 Rules design notes

- **Timestamps.** `createdAt`/`updatedAt` must equal `request.time`, so a
  client cannot back-date or forge them; the app writes
  `FieldValue.serverTimestamp()`. A queued offline write resolves the server
  timestamp when it syncs, so it still passes.
- **No clock comparisons for user times.** "Departure not in the past" stays
  in the app (it already is). Putting it in the rules would reject a journey
  planned offline that syncs after its departure — silently deleting it.
- **Trusted contacts get no access in Batch 7.** A contact is a phone number,
  not an account. Access for anyone but the owner exists only through
  function-written `viewerUids` on incidents and live shares, after an
  invitation the contact accepted (later batch).
- **Tests:** rules are tested with `@firebase/rules-unit-testing` against the
  Firestore emulator (Node and the Firebase CLI are installed; the emulator
  also needs JDK 21, which is not — §12) — owner
  allowed, other user denied, signed-out denied, every invalid field and
  every forbidden status change denied.

---

## 9. Phase 6/7 — backend decision and costs

### 9.1 Node.js API vs Cloud Functions

| | Cloud Functions (2nd gen) | Separate Node.js API |
|---|---|---|
| Hosting, scaling, TLS | Managed | You run it (Cloud Run, a VM…) |
| Auth | `request.auth` is the verified Firebase user in callables; triggers run as the project | You verify ID tokens yourself |
| Firestore triggers, schedules, Auth events | Built in | You build or poll |
| Secrets | Secret Manager, built in | You manage them |
| Cost at SafeRide's size | Free tier on Blaze: 2M invocations, 400K GB-s, 200K CPU-s a month | A always-on server costs money from day one |
| When it would win | — | Heavy relational queries, long-running jobs, a large existing Node codebase, or a need to leave Firebase |

**Recommendation: no separate backend.** Cloud Functions in TypeScript in a
`functions/` folder of this repository, deployed with the Firebase CLI, in
the same region as Firestore. None of SafeRide's requirements (pushes,
escalation, invitations, reminders) needs anything Functions lacks.

### 9.2 Spark vs Blaze (official pricing page, checked 2026-10-31)

| Product | Spark | Needs Blaze |
|---|---|---|
| Authentication, email/password (incl. reset and verification emails) | Yes — up to 50K monthly active users at no cost | — |
| Phone-number sign-in (SMS) | No | Yes (billed per SMS) — **SafeRide does not need it** |
| Cloud Firestore | Yes: 50K reads, 20K writes, 20K deletes a day; 1 GiB stored; 10 GiB egress a month | Beyond those quotas |
| Cloud Functions | **No** | Yes (free tier above) |
| Cloud Storage (photos, files) | **No** (Blaze even for small buckets) | Yes — SafeRide stores no files |
| Cloud Messaging | No-cost | No — but *sending* needs Functions, which needs Blaze |
| App Check | No-cost within each provider's quota | — |

**Batch 7 runs entirely on Spark** (Auth + Firestore). Blaze arrives with
the first Cloud Function, i.e. with the first push, SOS or sharing feature.
Blaze keeps the same free quotas; set a **budget alert** (budgets alert, they
do not cap) on day one.

### 9.3 Cost-conscious choices

- **One listener per data set, owned by the repository** (profile, the
  latest 50 journeys, the contacts). Screens read the repository's cache;
  they do not open their own queries. A cubit reload costs nothing.
- **Page journeys by 50**, never "all". A user's typical session then costs
  roughly 1 (profile) + ≤ 50 (journeys) + ≤ 20 (contacts) document reads on a
  cold start, and almost nothing afterwards (the cache serves the rest;
  listeners resumed within 30 minutes are charged only for changes).
  Spark's 50K reads a day therefore covers several hundred daily active
  users — enough for testing and an early pilot.
- **No per-push inbox writes** until an inbox exists; **no location
  history**; one overwritten live-share document with a rules-enforced
  minimum interval.
- **No Storage**, no phone auth.
- **Two Firebase projects:** `saferide-dev` (Spark, for development and the
  emulator) and `saferide-prod`. Tests use the emulator and cost nothing.

### 9.4 Region

Firestore supports **`me-central2` (Dammam)**, plus Doha and Tel Aviv; the
location **cannot be changed after the database is created**. Choose Dammam
for Saudi users and data-residency expectations under the PDPL, and deploy
Functions to the same region. Firebase Authentication's own user records are
not region-selectable. That belongs in the privacy policy SafeRide will need
anyway (§12).

---

## 10. Phase 8 — Android and iOS requirements

### 10.1 Common

- `flutterfire configure` (FlutterFire CLI 1.4.1 is installed) generates
  `lib/firebase_options.dart` and the platform files below; run it per
  project (dev/prod) — with flavors later if both must ship from one
  codebase.
- `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  in `main.dart`, after `WidgetsFlutterBinding.ensureInitialized()` and
  before `setupServiceLocator()`.

### 10.2 Android

| Requirement | Today | Action |
|---|---|---|
| Final application id (Firebase registers the app by it) | `com.example.basecode` | **Blocker** — owner chooses the reverse-domain id (CLAUDE.md §0 step 2) |
| Release signing key (its SHA-1/256 go into the Firebase project; Play App Signing adds Google's) | Debug key | Create the upload keystore; keep `key.properties` out of git (already ignored) |
| `google-services.json` + the `com.google.gms.google-services` Gradle plugin | — | flutterfire adds both |
| minSdk ≥ 23 | 24 | Nothing |
| INTERNET permission in the main manifest | Present (CLAUDE.md §12) | Nothing |
| Notifications (with FCM): `POST_NOTIFICATIONS` runtime permission on Android 13+, a default channel in the manifest | — | With FCM |
| Background location (later, only if ever needed): `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` (asked separately, from settings on Android 11+), a foreground service with `foregroundServiceType="location"` and `FOREGROUND_SERVICE_LOCATION` on Android 14+, plus Google Play's background-location declaration and review | — | Not planned. Foreground-only sharing (the app open, or a visible foreground service) is the realistic first version |

### 10.3 iOS (needs a Mac with Xcode — this development machine is Windows)

| Requirement | Today | Action |
|---|---|---|
| Deployment target **iOS 15** (Firebase Apple SDK 13.2 declares `.iOS(.v15)`) | 13.0, no Podfile yet | Raise in the Xcode project; the Podfile (generated on first `pod install`) gets `platform :ios, '15.0'` |
| Bundle id (final) | Template default | Owner decision, same as Android |
| `GoogleService-Info.plist` in `Runner` | — | flutterfire |
| Push (with FCM): Push Notifications capability, Background Modes → Remote notifications, an **APNs auth key** uploaded to Firebase | — | With FCM |
| App Check: App Attest capability | — | With App Check |
| Location (later): `NSLocationWhenInUseUsageDescription`; for background, `NSLocationAlwaysAndWhenInUseUsageDescription`, Background Modes → Location updates, and App Store review justification | — | Not planned |
| App Store privacy labels and an account-deletion path | — | Before submission |

### 10.4 Background execution — what Firebase does not do

- **No background GPS.** Firebase has no location API. Background location is
  the location plugin, the OS permissions, a foreground service on Android,
  and store review — each a product decision, not a Firebase setting.
- **Background code is limited.** A Dart background-message handler runs
  briefly and only for data messages; iOS may not deliver data-only messages
  at all when the app is killed. Anything that must happen reliably runs in a
  Cloud Function, not on the phone.
- **Offline writes do not sync in the background.** They sync the next time
  the app runs with a connection.

---

## 11. Phase 9 — Batch 7 implementation plan

### 11.1 Before coding (owner decisions, in this order)

1. **Application id / bundle id** (blocks Firebase app registration).
2. **Firebase projects**: create `saferide-dev` (Spark). Create
   `saferide-prod` later, when a release is near.
3. **Firestore region**: `me-central2` (Dammam) recommended — permanent.
4. **Authentication settings**: enable Email/Password; keep email
   enumeration protection on; set the password-reset and verification email
   templates (Arabic and English).
5. **Existing local data**: recommended — **start fresh**. Today's accounts
   are demo accounts on single phones; migrating them would need their
   passwords. On first launch after the update, a notice explains that
   accounts now live online and asks the user to register again. The old
   secure-storage keys are deleted.
6. **Release keystore** (needed for prod and App Check; can trail the dev
   build).
7. **JDK 21** on the development machine, for the Firebase emulators (rules
   tests).

### 11.2 Packages (versions current on pub.dev, 2026-10-31)

Mandatory:

| Package | Version | For |
|---|---|---|
| `firebase_core` | ^5.1.0 | Initialization |
| `firebase_auth` | ^7.0.1 | Accounts, session, reset, deletion |
| `cloud_firestore` | ^7.1.0 | Profile, journeys, contacts |
| dev `fake_cloud_firestore` | ^4.5.0 | Repository unit tests (built against cloud_firestore ^7.1.0) |
| dev `firebase_auth_mocks` | ^0.16.0 | Auth repository unit tests (built against firebase_auth ^7.0.0) |

Removed in the same change: `crypto` (the local password hash goes with
`LocalAuthRepository`). `flutter_secure_storage` stays only if something
still uses it after the cleanup; otherwise it goes too (Firebase keeps its
own session).

Not in Batch 7 (each arrives with its feature): `firebase_messaging`
^17.0.1, `cloud_functions` ^7.0.1, `firebase_app_check` ^0.5.1,
`flutter_local_notifications`, `geolocator`.

### 11.3 Configuration files

| File | New/changed | Notes |
|---|---|---|
| `lib/firebase_options.dart` | new (generated) | Committed: it holds identifiers, not secrets |
| `android/app/google-services.json` | new (generated) | Committed, like the above |
| `ios/Runner/GoogleService-Info.plist` | new (generated) | Committed |
| `android/settings.gradle.kts`, `android/app/build.gradle.kts` | changed | The Google services plugin; the final `applicationId` / `namespace` |
| `ios/Runner.xcodeproj` | changed | Deployment target 15.0, bundle id (on a Mac) |
| `firebase.json`, `.firebaserc` | new | Projects, emulator ports, rules/indexes paths |
| `firestore.rules` | new | §8.2, the `users/**` part |
| `firestore.indexes.json` | new | Empty for Batch 7 (only automatic indexes are needed) |

### 11.4 Code

**New files**

| File | Responsibility |
|---|---|
| `lib/core/firebase/firestore_paths.dart` | `users/{uid}`, `journeys`, `contacts` path helpers — the only place collection names are written |
| `lib/core/firebase/timestamp_converter.dart` | `JsonConverter<DateTime, Object?>`: Firestore `Timestamp` ↔ UTC `DateTime`; a pending (null) server timestamp reads as the write's local time |
| `lib/features/authentication/data/repository/firebase_auth_repository.dart` | `AuthRepository` + `SessionReader` over Firebase Auth and `users/{uid}`; exception → `AuthFailureCode`; profile listener; reset; deletion; after sign-out, `terminate()` + `clearPersistence()` |
| `lib/features/journeys/data/repository/firestore_journey_repository.dart` | `JourneyRepository` over `users/{uid}/journeys`; one listener (latest 50, paging); the planned-only rule mirrored before writing; offline timeout handling |
| `lib/features/safety/data/repository/firestore_trusted_contacts_repository.dart` | `TrustedContactsRepository` over `users/{uid}/contacts`; one listener; the 20 cap and the digit duplicate check on the device |
| `lib/features/authentication/presentation/pages/forgot_password_page.dart` (+ its widgets) | Email field, Send, a neutral "if an account exists…" confirmation |
| `firestore.rules`, `firestore.indexes.json`, `firebase.json` | §11.3 |
| `test/firestore_rules/` (Node, `@firebase/rules-unit-testing`) | Rules tests against the emulator |

**Changed files**

| File | Change |
|---|---|
| `lib/main.dart` | `Firebase.initializeApp` before DI |
| `lib/core/di/service_locator.dart` | Register `FirebaseAuth.instance` and `FirebaseFirestore.instance`; register the three Firebase repositories under the existing interfaces (`SessionReader` = the auth repository, as today); drop the local ones |
| `auth_repository.dart` | `sendPasswordReset`, `deleteAccount` |
| `auth_failure.dart` | Codes from §3.4 (`invalidCredentials`, `invalidEmail`, `weakPassword`, `tooManyRequests`, `network`, `requiresRecentLogin`, `disabled`); `noAccount` and `wrongPassword` removed |
| `account_cubit.dart`, `auth_cubit.dart` | Delete-account and reset actions; new codes |
| `login_page.dart`, `login_footer.dart`, `auth_notices.dart` | One credentials error; "Forgot your password?" → the reset route |
| `profile_page.dart` (+ a confirm dialog with password) | Delete account; "Signed in as …" instead of "Saved on this phone only" |
| `user_model.dart`, `journey_model.dart`, `trusted_contact_model.dart` | Timestamp converter; `phoneDigits` on contacts; regenerate with build_runner |
| `startup_cubit.dart` | Waits for the first auth state (still with its timeout and retry) |
| `app_routes.dart`, `app_router.dart`, `app_back_dispatcher.dart` | `forgotPassword` route (task page), back → login |
| `assets/translations/{ar,en}.json` | New errors and reset copy; **rewrite every "on this phone" string** (~20, listed by `grep -n "on this phone" assets/translations/en.json`), including About's "Kept on this phone" section |
| `CLAUDE.md` | §0, §1, §2, §3, §6, §9 (now real), §10, §11, §14, §16 — the local-auth decisions become the Firebase ones |
| Existing tests | Fakes move to the new interfaces; `service_locator_test` runs over the Firestore and Auth fakes |

**Deleted** (same change, per the clean-code rule): `local_auth_repository.dart`,
`password_hasher.dart`, `local_account_model.dart` (+ generated files),
`local_journey_repository.dart`, `local_trusted_contacts_repository.dart`,
and their tests.

### 11.5 Testing requirements (mandatory)

- **Repository unit tests** over `fake_cloud_firestore` and
  `firebase_auth_mocks`:
  - Each account sees only its own documents.
  - Planned-only edits; closing changes only the status.
  - The 20-contact cap and duplicate digits.
  - Exception → failure-code mapping.
  - Sign-out cancels listeners and clears the cache.
  - Deleting an account removes its data.
- **Rules tests** (emulator): owner allowed; another user, signed-out and
  forged-field writes denied; reopening a closed journey denied; timestamps
  forged denied.
- **Widget tests:** login's merged error; forgot-password flow; delete
  account (cancel and confirm); the startup decision offline with a session
  (opens Home, not welcome).
- **Device checks** (both languages, both themes):
  - Register, sign out and sign in on a second install with the same account (data follows).
  - Airplane mode (cached data shown, writes queue and sync).
  - Password reset email received in Arabic and English.
  - Delete account.
  - A release APK.
- `flutter analyze` clean, all tests green, and the CLAUDE.md verification
  list (§14).

### 11.6 Optional in Batch 7 (or right after)

- App Check in **monitoring** mode (Play Integrity / App Attest / debug
  provider) — enforcement waits for Play distribution (§7.4).
- Email verification banner on Profile.
- The `saferide-prod` project and flavors.
- Crash reporting (not requested so far — a product decision).

### 11.7 Later batches (designed here, not scheduled)

FCM + Cloud Functions + Blaze (first push feature) → invitations and
`linkedUid` → journey sharing (`liveShares`, foreground location) → SOS and
escalation (`incidents`, SMS provider in Secret Manager) → background
location only if a product decision and the store reviews allow it.

---

## 12. Risks and limitations

| Risk | Impact | Mitigation |
|---|---|---|
| The application id is still the template's | Firebase cannot be registered properly; changing it later means a new app for every existing install | Decide it before Batch 7 starts |
| Awaiting Firestore writes offline hangs the UI | Buttons spin forever on a bad connection | Short timeout + "will sync" state (§6.2) |
| A queued write rejected later by the rules vanishes from the cache | Silent data loss | Rules never depend on the client's clock or on facts the client could not know; rules tests cover every valid write |
| Firestore cache survives sign-out | The previous account's cached data stays on the phone (the app never queries it, but the files remain) | Queries only ever use the signed-in uid; `terminate()` + `clearPersistence()` after sign-out; clearing is not a secure erase (§6.2) |
| Listener per screen instead of per repository | Read costs multiply | One listener per data set in the repository (§9.3) |
| Email enumeration protection merges login errors | Users can't tell a wrong email from a wrong password | Expected trade-off; the copy says "email or password" |
| App Check enforced too early | Sideloaded test APKs stop working | Monitor first; enforce after Play distribution |
| iOS cannot be built on this Windows machine | iOS config and push can't be verified here | A Mac (or CI with macOS) before any iOS release |
| Firestore region is permanent; Auth data is not region-selectable | Data-residency questions | Choose Dammam up front; disclose in the privacy policy |
| Saudi PDPL and app-store privacy duties: privacy policy, consent for contacts' numbers, account deletion | Store rejection, legal exposure | A real privacy policy before release (today's About screen is not one); account deletion in Batch 7; consent built into any feature that messages contacts |
| The Firebase emulators need **JDK 21**; this machine has only JDK 17 (confirmed 2026-10-31: firebase-tools 15.28.1 refuses to start them) | Rules tests can't run locally; the §8.2 draft has **not been compiled yet** | Install JDK 21 (and point `JAVA_HOME` at it) as the first step of Batch 7, then compile and test the rules before anything is deployed |
| Vendor lock-in | Moving off Firebase later costs effort | Contained: Firebase types stay inside three repositories behind interfaces |
| Users expecting tracking or alerts from "safety" | False reassurance | The honest-copy rule stays: nothing claims sharing, tracking or alerts until each is built and verified |

---

## Sources (checked 2026-10-31)

- Firebase pricing: <https://firebase.google.com/pricing>
- Firestore locations: <https://firebase.google.com/docs/firestore/locations>
- Firebase Apple SDK platforms (`Package.swift`, firebaseVersion 13.2.0): <https://github.com/firebase/firebase-ios-sdk/blob/main/Package.swift>
- Play Integrity API quotas: <https://developer.android.com/google/play/integrity/setup>
- Email enumeration protection: <https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection>
- `clearPersistence()` (instance must be stopped; not a secure erase): <https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/FirebaseFirestore/clearPersistence.html>
- `Query.snapshots()` parameters (no server-timestamp option) and `GetOptions`: <https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/Query/snapshots.html>, <https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/GetOptions-class.html>
- Package versions: pub.dev API for each package named in §11.2
