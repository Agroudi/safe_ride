# SafeRide — production readiness (Batch 14, 2026-11-04)

The state of the app at the end of the planned batches: what works, what was
actually tested, and what stands between it and a store.

**SafeRide is not ready for release.** It is ready for testing on real phones.
It **cannot notify trusted contacts**: the project stays on Firebase's Spark
plan, where nothing can run the server side of that feature, and the app says
so wherever it matters.

"Emulator-tested" below means Android API 36 with simulated fixes. **Nothing in
this project has been tested on a physical phone, and nothing on iOS at all.**

## 1. Implemented features

| Feature | Status |
|---|---|
| Register, login, password reset, sign-out, session | Implemented; emulator-tested against the live project (batch 7) |
| Profile, language, theme, Arabic RTL and English LTR | Implemented; emulator-tested |
| **Account deletion** | Implemented; **unit-tested only** (fakes). Never run against live Firebase |
| Country selection | Implemented; emulator-tested, offline too |
| Emergency numbers, 7 countries, offline | Implemented; emulator-tested. Checked against official sources 2026-11-03 |
| Dialer (opens the phone app; the user presses call) | Implemented; emulator-tested with one number, no call placed |
| Trusted contacts (the list) | Implemented; emulator-tested |
| Journeys: plan, edit, cancel, complete | Implemented; emulator-tested |
| Pre-journey checklist | Implemented; emulator-tested |
| GPS tracking, route, speed, distance | Implemented; **emulator-only**. Simulated fixes report speed 0, so real speed was never seen |
| Android background recording | Implemented; emulator-only. OEM battery managers untested |
| Incident detection | Implemented; **emulator-only, not validated**. Thresholds are engineering starting points. It has never seen a real deceleration |
| 15-second safety check, in the app | Implemented; emulator-tested |
| Local safety notification | Implemented; the notification, countdown, timeout and action were emulator-tested through a temporary probe screen, not through a real safety check |
| "I'm safe" from a notification, process killed | Same probe, emulator-only |
| Locked-screen safety confirmation | **Not verified.** Shows only if the phone's settings allow it |
| Trusted-contact notifications | **Implemented but requires backend deployment. Off in this build; nothing is sent** |
| Invite codes, "Alerts for you" | Implemented; needs the backend; hidden in this build |
| Cloud Functions | Written; emulator-tested with a fake provider; **not deployed, by decision** |
| FCM | Receiving end only. Nothing sends |
| iOS | **Blocked by platform requirements**: never built |
| Location sharing, SMS, email, automatic calls | Not implemented, by decision |

## 2. Known limitations

- **A safety check alerts nobody.** With no answer, SafeRide records that and
  says trusted contacts could not be alerted. Nobody is told.
- **Detection is unvalidated.** It can miss real events and flag normal ones.
  It sees a stop's consequences, not an impact.
- A killed process stops everything until the app is opened. Swiping the app
  away ends the recording; force-stop or a restart ends all of it.
- 15 seconds is short for a phone in a pocket.
- Offline, lists show what the phone last saw with no "out of date" hint. An
  empty cache offline reads as "no journeys". About says what works offline.
- Offline saves say "added" or "saved" after a 4-second wait, though they are
  only queued; a later rule refusal would roll them back quietly.
- Route data stays in the account until the account is deleted: there is no
  per-journey deletion.

## 3. Backend deployment status

| Item | Status |
|---|---|
| Cloud Functions | **Not deployed. Will not be, on Spark.** The code stays in `functions/` |
| `firestore.rules` (Batches 13–14) | **Not deployed.** Live rules are Batch 10's |
| `firestore.indexes.json` | **Not deployed**; only the backend needs it |
| Firebase Auth, Firestore, FCM setup | Live and unchanged |

The undeployed rules change nothing a Spark build does: this build never touches
the collections they add, and account deletion needs only what the live rules
already allow. Deploying them is free and optional; it adds the closed rules
for those collections, which today fall to the catch-all "refuse".

## 4. Firebase plan requirements

**The project stays on Spark, by the owner's decision.** Everything this build
uses fits Spark: Authentication, Firestore, FCM receiving, rules deploys.
Spark's Firestore daily limits are in `firebase-architecture.md` §9.2; route
recording costs about 2 writes per 2 minutes of journey.

Trusted-contact alerts need Cloud Functions, so **Blaze**. Blaze also needs the
build flag, and `docs/escalation.md` §10 lists the steps and the copy to change.
There is no way to do this on Spark from the phone alone: sending a push needs
a server credential, which must never be in the app.

## 5. Security findings

**No client can read or change another account's data.** Every path is checked
by the owner rule, and 50 rules tests cover it from both sides. No secret is in
the tree or in git history.

Fixed in this batch:
- `.gitignore` did not cover keystores outside `android/`, `*.p8`, `.env`,
  `.runtimeconfig.json` or service-account files.
- `allowBackup` defaulted to true, so route points could reach cloud backups.
- Three logs could carry a file path containing a uid.
- An incident could be created without its check in the same write.
- A phone like `1------` passed the form and failed the rules.
- A malformed FCM message would have deleted a contact's device records.

Remaining:

| Risk | Severity |
|---|---|
| An owner can delete their own checklist and journey, then recreate one that starts on the old checklist. It only fools their own record | Low–medium |
| Route chunks: only the first and last points are validated, and a chunk can be rewritten after the journey ended. The owner's own data, with storage cost | Medium |
| No App Check: anyone with the app's public identifiers can call Firebase as a client, within the rules | Medium |
| `createContactInvite` has no rate limit, and safety-check requests are unbounded (backend only, inactive on Spark) | Low today |
| A contact's `receivedAlerts` keep a deleted user's name and phone (backend only) | Low today |
| A cached copy of a signed-out account's data stays in Firestore's local cache. The app queries only the signed-in uid | Low |

## 6. Privacy findings

| Data | Where | Kept until |
|---|---|---|
| Name, optional phone, language, country | Firestore; email in Firebase Auth | Account deletion |
| Trusted contacts: a third party's name and number, unverified | Firestore | Removed, or account deletion |
| Journeys, checklists | Firestore | Account deletion |
| Route points, precise | Phone, then Firestore | Phone copy deleted once synced; Firestore until account deletion |
| Incidents, location rounded to ~11 m | Phone only | Closed ones 90 days, at most 100 |
| Safety checks | Phone only | Finished ones 90 days, at most 50; unanswered ones until the cap or deletion |
| Device record (FCM installation id) | Firestore | Sign-out or account deletion |
| Escalation attempts | None in this build | n/a |

- **Account deletion** needs the password, deletes everything above from the
  account and the phone, then the sign-in. It stops the recording and any check
  first. A failure says it may be half done, and running it again finishes it.
  Local data goes first, so a failed deletion can lose unsent route points.
- **Sign-out** stops monitoring and keeps this phone's per-account files, so an
  unsent route still reaches the account on the next sign-in. Files are kept
  per uid, and no other account reads them.
- **Retention decision:** nothing is kept past deletion for audit. No legal need
  has been identified; **have that confirmed before launch**.
- **No privacy policy exists.** Both stores require one, and it needs a lawyer.
  Storing a third party's phone number should be covered in it.

## 7. Android limitations

- The recording needs a foreground service and its notice. Swiping the app away
  ends it.
- Doze and OEM battery managers (Xiaomi, Huawei, Samsung, Oppo) may kill it;
  **untested**.
- Battery: a fix every 2 s at high accuracy is the heaviest thing the app does.
  GPS with a screen off commonly costs several percent an hour, but **SafeRide's
  real figure is unmeasured**. The interval stays, because telling "still" from
  "no signal" needs it; detection would be weaker at a longer one.
- Lock-screen visibility and sound follow the user's settings. Do Not Disturb
  may silence the check.
- No full-screen intent, deliberately.
- The notification's direction follows the device language, not the app's.
- A fix's speed comes from the phone. Emulator fixes have none.

## 8. iOS limitations

**iOS is not production-ready and has never been built.** There is no Mac here,
no `ios/Podfile`, and the `AppDelegate` change has not been compiled.

Required, on a Mac:
- `GoogleService-Info.plist`, and the Firebase iOS app config.
- Signing: a team, and a provisioning profile.
- Capabilities: Background Modes › Location updates, Push Notifications with
  `aps-environment`, and an APNs key in Firebase. Optional: Time Sensitive
  Notifications.
- `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption`, the app icon.
- Arabic `InfoPlist.strings` for the location prompts (English only today).
- App Review: justification for background location.

Expected behaviour, **all unverified**: iOS may suspend or end the app during a
journey, so background recording and the 15-second timer cannot be relied on.
The notification has no countdown. A check may only be processed when the app
returns.

## 9. Required physical-device tests

On at least one Samsung, one Xiaomi or Huawei, and one Pixel, then an iPhone:

1. **Drive a real route** of 30+ minutes: distance against an odometer, speed
   against a car's, route shape, gaps in tunnels.
2. **Battery:** one hour of recording, screen off, then screen on, with `adb
   shell dumpsys batterystats`. Check heat too.
3. **Background survival:** an hour with the screen off under each OEM's default
   battery settings. Note when the recording dies.
4. **Detection:** hard braking in a safe, empty place; traffic jams; red lights;
   fuel stops; parking. Count false alarms and misses. **Never stage a crash.**
5. **Safety check:** the full flow in the app, screen on, screen off, locked,
   Do Not Disturb, notifications off.
6. **"I'm safe" from a real notification,** in the last seconds of a countdown.
7. **Offline:** airplane mode for a journey, then reconnect. Check route counts.
8. **Account deletion against the live project** with a throwaway account, then
   confirm in the Firebase console that its documents and sign-in are gone.
9. **Arabic RTL, large text, TalkBack and VoiceOver** on a real screen.
10. **Release build** from a real keystore.

Never contact real emergency services during any test.

## 10. Remaining release blockers

| # | Blocker | Who |
|---|---|---|
| 1 | Physical-device tests (§9), especially account deletion, background survival and detection | Owner |
| 2 | A published privacy policy, and a web page for account deletion (Play asks for one) | Owner, with legal advice |
| 3 | Release keystore: `android/key.properties` is wired, no keystore exists | Owner |
| 4 | Play Console: location foreground-service declaration with a video, and the Data Safety form | Owner |
| 5 | Decide what the safety check is for without alerts: as built, it records and warns but tells nobody | Owner |
| 6 | Launcher PNGs: legacy Android mipmaps and the iOS icon are still Flutter's | Designer |
| 7 | Cairo is downloaded at first launch; bundle it so a first offline start shows it | Developer |
| 8 | Liability wording: review the safety copy with a lawyer before calling this a safety app in store text | Owner |
| 9 | iOS: everything in §8, if iOS is in scope | Owner, with a Mac |
| 10 | App Check (monitoring first) | Developer |

## Appendix: state-transition audit

Traced in the code and covered by tests, Batch 14. "Tests" means unit or widget
tests with fakes, not a device.

| Transition | Result |
|---|---|
| Second start of a journey | Joins the same recording; one location subscription |
| Start of another journey while one records | Answers `otherJourney`; one at a time. Was: could get the first one's answer |
| Journey completed or cancelled, any screen, offline too | Recording stops; pending check cancelled |
| Stop arriving twice (local write, then server) | Runs once. Was: possible uncaught error |
| Stop failing on a full disk | Recording ends on screen; file finished on next launch. Was: stuck, blocking later journeys |
| Sign-out | Tracker, engine, check and timers stop; speed and queued-sync state cleared. Was: speed and a global offline flag leaked to the next account |
| Account deleted | Recording and check stop first, then everything goes |
| New journey | Fresh engine; nothing carried over |
| App reopened on the same journey | New engine; an old open event can no longer swallow a new one. Was: it could |
| App reopened mid-journey | New segment, no distance across the gap. Was: an inaccurate first fix could hide the gap |
| Tracking interruption | Stored at low confidence; never asks a check |
| Low-confidence incident | Stored; never asks a check |
| `pending` → `confirmedSafe` | Once; a second tap is `notPending` |
| `pending` → `timedOut` → `escalationReady` | Once, at the deadline, re-read from storage |
| `confirmedSafe` → anything | Refused; the timer re-reads and stops |
| `cancelled` → anything | Refused; never reported |
| Tap on the notification just before the deadline | Wins over the timer if already written down. Was: the timer ignored it |
| Tap after the deadline | Too late; the check stays timed out |
| Failed write during a check | Looked at again in 5 s. Was: no timer until the next resume |
| `escalationReady`, no backend | Stays on the phone; `serviceUnavailable`: nobody alerted, nothing to retry |
| Anything the server says, no backend | Ignored: never shown as sent |
| Expired check | Called "no answer", never an accident |
| Route file lost a point | Count corrected; sending ends. Was: an endless write loop that also blocked later journeys |
| Refused Firestore listener | Retried after 30 s. Was: a tight loop for as long as Home was open |
| One unreadable document | Skipped. Was: every screen on that list, and the safety check, could hang |

Accepted, millisecond windows: a journey ending during a start's awaits, and a
stored event read just before another write changes it.
