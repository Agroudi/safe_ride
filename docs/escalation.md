# SafeRide — safety notifications and trusted-contact alerts (Batch 13)

What happens when nobody answers "Are you okay?", how to set it up, and what
it cannot promise. `CLAUDE.md` §16 holds the decisions;
`docs/firebase-architecture.md` the wider Firebase design.

> **Status: off.** The project stays on Firebase's Spark plan, by the owner's
> decision, and Cloud Functions need Blaze. So `AppFeatures.contactAlerts` is
> off: **no alert reaches anyone**, the phone sends no request, and the app says
> trusted contacts could not be alerted. Everything below about the backend
> describes code that is written and emulator-tested but not running. Local
> safety notifications (§2) are on.

## 1. The flow

```
Phone                                     Firebase
─────                                     ────────
SafetyCheckService
  15 s pass, no answer
  → escalationReady
EscalationSync
  one batch: safetyChecks/{id}  ───────▶  Security Rules: owner only, shape,
           + incidents/{id}               deadline passed, journey exists
  (offline: Firestore's disk queue)             │
                                                ▼
                                          onSafetyCheckCreated (retry: true)
                                            account usable?
                                            transaction: escalations/{checkId}
                                              created once, or found
                                            eligibility (eligibility.ts)
                                            resolve reachable contacts
                                            per contact: claim attempt →
                                              receivedAlerts copy → FCM →
                                              record what FCM said
EscalationCubit  ◀── live read ─────────  escalations/{checkId}
  shows only what that record says        retryEscalations (every 5 min)
                                            sends what is due, or stopped
```

Everything on the phone is a **claim**. The trigger takes the user and check
ids from the document's path, which the rules tied to the signed-in owner, and
checks that the documents agree with each other.

## 2. Local safety notifications

`SafetyNotifications` (interface), `LocalSafetyNotifications`
(`flutter_local_notifications`), driven by `SafetyCheckService`.

- Shown only while the app is **not** in the foreground, so it never doubles
  the prompt. It moves between the two on hide and resume.
- One notification id, and the service remembers what is showing: never a
  duplicate.
- "I'm safe" on the notification runs in **its own isolate**, with no service
  locator. It writes the moment of the tap to
  `safety_checks/answers/<checkId>` first, then pings the app if it is alive.
  The service applies it at once, or on the next launch. What counts is when
  the finger came down: an answer in time is honoured even if read later.
- Tapping the notification opens the app, where `SafetyCheckHost` shows the
  prompt.
- At the deadline Android removes it by itself (`timeoutAfter`), even if the
  process died; if the app is alive it posts "No answer recorded".
- Notifications off: the journey screen says a check can then be answered
  only on screen, and offers to turn them on (prompt, then settings).
- A failure in the notification layer never touches the countdown.

**No full-screen intent, deliberately.** `USE_FULL_SCREEN_INTENT` is reserved
by Android for calling and alarm-clock apps, needs a store declaration, and
SafeRide is neither. The channel is `Importance.max`, category `alarm`,
visibility `public`. **Whether it appears on the lock screen is the user's
setting**; the text holds nothing private.

## 3. Eligibility (`functions/src/eligibility.ts`)

An escalation is **rejected**, with its reason recorded, unless all hold:

| Check | Reason |
|---|---|
| Account exists and is not disabled | `accountUnavailable` |
| Check exists, names this uid, references are plain ids | `checkInvalid` |
| Status is `escalationReady` | `notEscalationReady` |
| Deadline has passed on the server's clock | `deadlineNotPassed` |
| Incident exists in this account, same journey, points back at this check, a movement event of medium or high confidence | `incidentInvalid` |
| Journey exists in this account | `journeyMissing` |
| Journey still active (a closed one means the user was there) | `journeyNotActive` |
| Less than 24 h since the deadline | `stale` |
| No alert for this journey in the last 30 minutes | `duplicateJourney` |
| Fewer than 3 alerts for this account in 24 h | `rateLimited` |

Then, with nobody reachable, the status is `noRecipients`: `noContacts`, or
`noReachableContact` when none is linked, the link is for an older number,
their account is closed, or they have no registered phone.

## 4. Idempotency

| Cause | What stops it |
|---|---|
| Repeated taps, restarts | `EscalationSync` writes once per check per run |
| A second write after a restart | Rules: a request is never rewritten |
| Offline retries | Firestore's queue; same document id |
| Duplicate events, function retries | Escalation id **is** the check id, created in a transaction |
| Two phones, two checks, one journey | `duplicateJourney`, decided inside that transaction |
| Two runs sending at once | Each attempt is claimed in a transaction, with a 2-minute lease |
| A crash after FCM accepted, before recording | A resend carries the same collapse key and tag, so it replaces rather than stacks. This is the one case where FCM may be called twice |

## 5. Channels

| Channel | Status |
|---|---|
| **FCM push** | **The only one implemented.** Reaches a contact who has SafeRide, accepted an invite, and has a registered phone |
| SMS | **Not implemented.** No provider, no credentials |
| Email | **Not implemented.** Contacts have no email address, and there is no provider |
| Phone call | **Never.** Nothing calls anyone or any emergency service |

**A trusted contact who never accepted an invite receives nothing.** The app
says so on the contact and in the status.

Why invites: a contact is a name and an unverified number, and no account has
a verified number. Matching accounts by phone number would let anyone claim a
number and receive another person's alerts. So the user creates a one-time
code (10 characters, 72 hours, stored only as a SHA-256 hash), hands it over
in person or by their own message, and the contact enters it under Safety. The
server writes `contactLinks/{contactId}`; a change of the contact's number
ends the link.

### Status words

| Attempt status | Means |
|---|---|
| `sending` | Claimed, request in flight (or crashed: the lease expires) |
| `accepted` | FCM took the request. `delivery` stays `unknown` |
| `retryScheduled` | Passing failure; `notBefore` says when (1, 5, 15 minutes) |
| `failed` | Permanent, or retries used up; `failure` holds the provider's code |

There is **no "delivered"**: FCM's send API does not report delivery or
reading, and no client can write this record.

### Adding SMS later

Implement `AlertChannel` (`functions/src/channel.ts`) and keep the provider's
key in Secret Manager (`defineSecret`), never in the repository or the app. It
needs a provider account, per-message charges that vary by country (check the
provider's current price list), and in the Gulf states usually a registered
sender ID, which can take weeks. Texting someone who never agreed also needs
a legal review.

## 6. What a contact sees

Push preview: the user's name, "unusual movement", a sudden slowdown or a long
stop, the time (in UTC, as the server does not know the contact's zone), that
the safety check got no answer, that the journey was in progress, that this
confirms nothing, that emergency services were **not** contacted, and to try
calling. Arabic or English, by the contact's profile language.

In the app (`Safety › Alerts for you`): the same, the time in their own zone,
and Call when the user's profile has a number. Call opens the phone app on the
contact's own tap.

The words are tested: never "accident", "injured" or anything saying help was
called.

## 7. Location and privacy

**No location is shared. That is the decision, not an omission.** SafeRide
cannot yet offer the consent, revocation, expiry and access control that
sharing needs, and a contact's first move is to call. So:

- The request leaves out the incident's stored position; the rules refuse a
  location field.
- `receivedAlerts` holds name, number if any, event type and times. No route.
- No extra GPS is recorded or uploaded for an alert.
- Contacts read only their own `receivedAlerts`, never the user's account.
- Logs hold no tokens, contact details or location. Attempts hold contact ids
  and provider message ids, never a phone number.

Stored server-side per unanswered check: journey and incident ids, event type,
confidence, times. Retention is not automated yet.

## 8. Offline

The request goes into Firestore's disk queue and survives a restart.
`escalationQueuedAt` and `escalationSyncedAt` are stored on the check;
`timedOutAt` never changes; the server keeps `eventAt`, `requestedAt`,
`createdAt` and `dispatchedAt` apart. The app says contacts can't be alerted
until the phone is back online. The queue only moves while SafeRide is
running. A request reaching the server over 24 hours late is rejected as stale.

## 9. Platform limits

Nothing here guarantees that anyone notices anything.

| | Android | iOS (**nothing tested: no Mac here**) |
|---|---|---|
| Permission | `POST_NOTIFICATIONS` on 13+; asked with location, or from the journey note | Asked from the journey note or the location step |
| Lock screen | Depends on the user's setting | Depends on the user's setting |
| Background | The recording's foreground service keeps the process, and the 15-second timer, alive | May suspend the app; the timer may not fire until it returns |
| Process killed | A shown notification stays until its deadline and its action still works (verified). The check times out on next launch | Same intent, unverified |
| Force-stop | Android removes the notifications and blocks everything until the app is opened | Swiping the app away ends it the same way |
| Restart | Nothing runs until the app is opened | Same |
| Countdown | System chronometer | None: static text |
| Action | Background isolate | Needs the category registered at launch; in `AppDelegate`, unverified |
| Time-sensitive | n/a | Needs the Time Sensitive Notifications capability in Xcode |
| Text direction | Follows the device language, not the app's | Same |
| Channel name | Language of first launch until the app restarts | n/a |
| FCM | May be delayed by Doze and OEM battery managers, dropped if the phone stays offline past FCM's storage period | Needs an APNs key; may be throttled |

**A process killed mid-check, with no notification answered, reaches contacts
only when the app next opens**: the backend does not know a check is running.

## 10. Setup and deployment

Nothing here is a secret: FCM uses the functions' own service identity, and
**no key goes in the app or the repository**.

**None of this applies while the project stays on Spark.** It is here for a
future decision.

1. **Upgrade the project to Blaze** in the Firebase console (a billing
   account; set a budget alert). See `firebase-architecture.md` §9.2 for the
   free allowances. At SafeRide's size the expected charge is near zero, with
   a little Artifact Registry storage for the function images.
2. **Check region access.** Functions run in `me-central2`, because a
   Firestore trigger must match the database's location. Google's Cloud
   Scheduler page footnotes Dammam access; if a deploy is refused, that is
   the first thing to look at. Eventarc's page lists `me-central2` but does
   not name it for Firestore triggers explicitly: **this is unconfirmed until
   the first deploy**.
3. Deploy, after the tests pass:

   ```bash
   cd functions && npm ci && npm test
   cd ../test/firestore_rules && npm test
   ```

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,functions --project saferide-a9d9f
   ```

   Deploy the rules **with or before** a build of the app that sends requests:
   under the old rules every request is refused. The `escalations`
   collection-group index must finish building before the retry sweep works.
4. **iOS, on a Mac:** `GoogleService-Info.plist`, the Push Notifications
   capability, an APNs key in Firebase, optionally Time Sensitive
   Notifications; then build, because the `AppDelegate` change has not been
   compiled.
5. **Build with the flag:** `--dart-define=CONTACT_ALERTS=true`. Change the
   copy written for "off": `journeys.safetyCheck.explain`,
   `journeys.safetyCheck.notice.noAnswer`, `journeys.safetyCheck.notice.off`,
   `journeys.notTracked`, `journeys.tracking.needs.denied.body`, `safety.note`,
   `safety.contacts.notice`, `safety.journeys.cannot.alerts`,
   `about.notYet.alerts`, `about.stored.safety`, and the privacy documents.
6. **First live test:** two test accounts you own, one inviting the other. Never
   a real emergency number.

Environment: no environment variables. The emulator needs JDK 21 first on
`PATH` (CLAUDE.md §14). The app's functions region is set in
`service_locator.dart`, the backend's in `functions/src/index.ts`.
