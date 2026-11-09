# SafeRide — location and journey sharing (Batch 16)

A user can send a private link that shows where they are, or a journey in
progress, to someone with no account. This page is the design, the security
model, what it costs, and what it does not do.

**Sharing is voluntary and is not an emergency feature.** Nothing here alerts
anyone, watches the map, or touches trusted-contact alerts. It is also independent
of connections between accounts (`docs/connections.md`): being connected opens no
link, and ending a connection stops none.

**State:** the rules and the web viewer were deployed on 2026-11-05. Everything in
§10 was tested on the Firebase emulators; no real share has run on the live project.

## 1. What is shared

| | Current location | Journey in progress |
|---|---|---|
| Position and when it was last updated | Yes | Yes |
| Live, paused or stale | Yes | Yes |
| Start and destination (the user's words, with a pin if they set one) | No | Yes |
| Route recorded so far, distance travelled | No | Yes |
| Finished | No | Yes |

**Never shared:** name, email, phone, the Firebase uid, the journey's id, contacts,
other journeys, safety checks, incidents. The recipient knows who sent the link
because of who sent it. Start and destination are the user's own words, so
"Home" is shared as "Home": the start screen says so.

One share at a time per account. A journey's share always ends with the journey.

## 2. Architecture

```
JourneyTracker ── trustedFixes, snapshots ──▶ LocationSharing ──▶ ShareRepository ──▶ Firestore
 (the one GPS                                  (one, app-wide)                         │
  subscription)                                                                        │
SharingPage ── ShareCubit ─────────────────────────┘             SharedViewRepository ◀┤
SharedViewPage ── SharedViewCubit ───────────────────────────────┘    web viewer ◀─────┘
```

- **One GPS subscription.** `LocationSharing` has no location code. It reads
  `JourneyTracker.trustedFixes`. A current-location share has no journey, so
  `JourneyTracker.watch()` keeps the tracker's own subscription open with nothing
  recorded or stored. A recording that starts meanwhile joins the same
  subscription, and the other way round. The tests assert one `listens`.
- **Separate from safety.** The tracker's `TrackingObserver` (detection) is not told
  about watching, sharing is not an observer, and neither knows the other exists. A
  failing share cannot reach recording, detection or the safety check. Nothing here
  touches `AppFeatures.contactAlerts`, `EscalationSync` or `functions/`.
- **In the journeys feature**, because it needs the tracker and the map widgets
  (§2 of `CLAUDE.md`: features do not import each other).

## 3. Firestore schema

**`shares/{token}`** — public to whoever holds the token. Rules cannot hide a field,
so what must stay private is simply not here. There is no `ownerUid`, on purpose.

| Field | Type | Notes |
|---|---|---|
| `kind` | `location` \| `journey` | Fixed at creation |
| `createdAt`, `updatedAt` | timestamp | Server time, enforced |
| `expiresAt` | timestamp | At most 12 hours ahead; can only be shortened |
| `tracking` | `waiting` \| `live` \| `paused` \| `ended` | |
| `location` | `{lat, lng, accuracy, fixAt}` | Absent until the first fix, and after a journey ends |
| `locationAt` | timestamp | Server time, enforced |
| `origin`, `destination` | `{name, lat?, lng?}` | Journey only, fixed |
| `journeyStatus` | `active` \| `finished` | Journey only |
| `distanceMeters` | number | Journey only |
| `routeChunks`, `routeVersion` | int | How many chunks; moves when the route does |

**`shares/{token}/route/{00000…}`** — `{chunk, points: [{lat, lng, seg}], updatedAt}`,
at most 200 points, at most 40 chunks.

**`users/{uid}/shares/{token}`** — `{kind, journeyId?, createdAt, expiresAt}`, the
owner's alone. It is the proof of ownership the public document cannot carry, and
how a share is found again after a restart or when the account is deleted. It holds
the raw token because the link must be shown again and the public document deleted:
a hash could do neither. It is a document about that share, not an unrelated one.

## 4. Security model

**The link is a bearer credential.** Anyone who has it can read that one share until
it ends. It is not impossible to discover in principle, and it is only as private as
the people it is sent to. Guessing is the part that is not practical: 256 random bits.

| Rule | How |
|---|---|
| Read only with the token | `allow get` on one document; `allow list: if false` |
| Expiry without the phone | `allow get: if resource.data.expiresAt > request.time`, the server's clock |
| Revocation | Stopping deletes the document; the next read is refused |
| Owner only writes | `exists(users/{auth.uid}/shares/{token})` |
| A leaked token cannot be claimed | The owner record can only be created in the same write as the public document, and is refused if that already exists |
| No extension | `expiresAt` can only go down; the owner record too |
| What it shares cannot be swapped | `kind`, `createdAt`, `origin`, `destination` are not in the changeable list |
| Times cannot be forged | `createdAt`, `updatedAt`, `locationAt` must equal `request.time` |
| Bad data | Coordinates in range, accuracy 0–50, keys listed, sizes bounded |
| Finished stays finished | No update once `journeyStatus` is `finished` |
| Undeletable link cannot happen | The owner record cannot be deleted before the public document |

A stopped, expired and invalid link answer identically (`403`), so a guess learns
nothing about whether a token ever existed. For the same reason the recipient
sees one "This share has ended" message for all three.

**Token.** 32 bytes from `Random.secure`, base64url, 43 characters. It is never a
journey id, a uid or anything derived. It appears in the link, the public document's
id and the owner's record, and nowhere else.

**Where a token can leak, and what was done:**

| Channel | State |
|---|---|
| Web server logs, Referer | After `#`, which browsers never send. `Referrer-Policy: no-referrer` as header, meta tag and on every fetch |
| App logs | Never logged: errors print only their type (`debugPrint('… ${e.runtimeType}')`) |
| Analytics, crash reports | The app and viewer have none |
| Third parties on the viewer page | MapLibre from jsDelivr (pinned, hash-checked) and OpenFreeMap tiles receive no token. CSP limits the page to those and Firestore |
| Search engines | `noindex` header and meta tag |
| **Firestore** | The viewer's request path holds the token, over TLS, to Google. Unavoidable: the token is the document id |
| **Browser history** | **Stays** on the recipient's device. A reload needs it |
| **Clipboard** | Copy link puts it there, where other apps or clipboard sync may see it. **Not preventable** |
| **The messaging app** | The link sits in the chat, and may be backed up or previewed. **Not preventable** |
| **Android** | When verified, a link opens the app; the token stays in that app's memory |

**Revocation cannot erase what was seen.** Screenshots, a copied link's earlier
views, and whatever a device cached stay. The app says so before stopping.

## 5. Lifecycle

**Start.** The screen says what is shared and for how long, and nothing happens until
Start. Then, in order: location access, the viewer page answers, both documents are
created in one transaction, and the share is **read back with no account**, as a
recipient would. Any failure means no link and no share left behind. A link is never
shown until it has been proved to work.

**Durations.** Current location: 30 minutes (default), 15 minutes, 1 hour, 3 hours.
Journey: until it finishes (default, at most just under 12 hours), 15 minutes, 30
minutes, 1 hour, 3 hours. The rules cap every share at 12 hours; the longest option
stays 5 minutes under, so a phone whose clock runs a little fast is not refused.

**A share ends when:**

| Event | What happens |
|---|---|
| The owner stops it | Publishing stops at once; public document, route and record are deleted in one batch. Offline, the delete waits in the queue, and the app says the link ends when it is back online or at its end time |
| It expires | The rules refuse reads from `expiresAt`, whether or not the phone is on. The phone deletes it when it next can |
| Its journey ends | Position removed, marked finished, `expiresAt` cut to 10 minutes, so the recipient reads "Journey finished". Then deleted. Offline: deleted outright |
| Stopped on another phone | The next publish finds it gone and stops |
| Sign-out | Publishing stops and the share is deleted, before the session ends. A failure never blocks signing out |
| Another account signs in | Publishing stops; nothing is touched. Rules would refuse it anyway |
| Account deleted | §7 |

**After a restart.** `recover()`, called where the recording is recovered: expired
records are cleared, journeys that ended are cleared, and a running share resumes.
A closed app publishes nothing, and the recipient sees the position go stale.

## 6. Publishing and the route

Fixes arrive every 2 seconds. Most are not sent.

| Rule | Value |
|---|---|
| Shortest time between positions | 15 s |
| Least movement for a new position | 10 m |
| Standing still | Confirmation (same position, new time) once a minute |
| Route extended | Once a minute, inside the same write as a position |
| No trusted fix for 20 s | `paused`, once |
| After a failed send | Wait 30 s |

**Trust.** The tracker passes only fixes that pass `RouteFilter` (valid, accuracy
50 m or better, not over 30 s old); `LocationSharing` also drops GPS jumps.

**Why transactions, not writes.** A plain write made offline waits in the phone's
queue and takes the server's time **when it lands**, so an hour-old position would
arrive looking live, behind a backlog. A transaction fails instead. Nothing is
queued, one send runs at a time, and offline only the newest position is kept. The
read inside it also reveals a share stopped elsewhere.

**The route.** The existing chunks sit under `users/{uid}/…`, so a recipient could not
read them without a uid in the path. Sharing keeps its own copy, thinned to a point
every 25 m, rounded to about 1 m. Chunks are rewritten whole, so a retry never
duplicates, and a position update never carries the route. `seg` is the recording's:
**no line crosses a gap**, on either viewer. It stops growing at 8,000 points (about
200 km) while positions continue.

**Live, stale, offline.** The recipient calls a position live only if it is under 90
seconds old **and** the document was heard from in the last 90 seconds, so a wrong
device clock cannot make an old position look live. Otherwise it reads "Not up to
date", drawn muted. The owner's status says "reaching your link", meaning the server
confirmed it. **Nothing can tell whether anyone looked.**

## 7. Account deletion

`FirestoreAccountData` reads `users/{uid}/shares` from the server, then deletes each
share's route, public document and record, before the rest of the account.
`LocationSharing.erase` stops publishing first. It is part of the existing flow: a
failure says so, and running it again finishes the job.

**Limit.** Without a backend, this only runs from the app. An account deleted any other
way (the Firebase console) leaves its share readable until `expiresAt`, at most 12
hours, and leaves the expired documents stored.

## 8. Web viewer, deep links, deployment

**Link:** `https://saferide-a9d9f.web.app/s#<token>`.

**Viewer.** `hosting/` is plain HTML and JavaScript: `s.html`, `share.js`,
`share-core.mjs` (the logic, tested with `node --test`), `share.css`, `share-config.js`.
No build, cookies or SDK. It reads over Firestore's REST API every 15 seconds, only
while the page is visible, and draws with MapLibre (OpenFreeMap's supported client).

**Android.** An intent filter on `/s` opens `SharedViewPage` with no account, so an
installed app handles the link. `autoVerify` needs `.well-known/assetlinks.json` live,
listing the signing key. **The file lists this machine's debug key, because no release
keystore exists.** Add the release key's fingerprint when it does, or links will open in
the browser for store builds. That is still a working link.

**iOS.** Universal Links need Associated Domains and an Apple team id, neither of
which exists here. On iOS a link opens the browser viewer.

**Deployed 2026-11-05.** After a change, deploy the rules first:

```bash
npx --yes firebase-tools@15.28.1 deploy --only firestore:rules --project saferide-a9d9f
npx --yes firebase-tools@15.28.1 deploy --only hosting --project saferide-a9d9f
```

If either is missing, Start fails with "Sharing isn't available yet" and no link.

**Build settings:** `--dart-define=SHARE_BASE_URL=…` and `SHARE_FIRESTORE_URL=…`. The
intent filter's host and `share-config.js` must match them.

## 9. Spark compatibility and cost

No Cloud Functions, no server, no scheduled jobs, no paid service. Firestore and
Hosting are both within Spark (reads 50K/day, writes 20K/day, deletes 20K/day, 1 GiB
stored; Hosting 10 GB stored, 360 MB/day transferred).

**Worst-case estimate: always moving, so every 15-second slot is used.** Rule
`exists()` and `get()` calls count as reads.

| One shared 30-minute journey | Writes | Reads |
|---|---|---|
| Owner: 120 positions (1 read in the transaction + 1 in the rules, 1 write) | 120 | 240 |
| Owner: 30 route updates (1 chunk write, 1 rule read) | 30 | 30 |
| Start, link check, finish | 5 | 5 |
| **Owner total** | **~155** | **~275** |
| Each viewer: 120 polls or listener updates, 30 chunk reads with their rule read | 0 | ~180 |

| Viewers | Reads per journey | Shared journeys a day before a limit |
|---|---|---|
| 1 | ~455 | ~110 (reads) |
| 3 | ~815 | ~60 (reads) |
| 10 | ~2,075 | ~24 (reads) |

Writes allow about 129 a day. Standing still costs about a quarter of this. A public
document is under 1 KB and a chunk at most about 14 KB. The viewer's own files are about
20 KB per load from Hosting (MapLibre comes from jsDelivr), so 360 MB/day is about
18,000 opens.

A viewer left open reads until the page is hidden or the share ends, so the cost is
bounded by the share's length.

**What Spark cannot do.** At the daily limit Firestore stops answering, and sharing stops
with everything else in the app, until the quota resets. Nothing warns anyone. A real
user base needs a plan for that, and that decision is the owner's.

## 10. What was tested

**Automated.** Rules: 25 tests against the emulator (`test/firestore_rules`). Dart:
the publisher, repositories, cubits, tracker and screens, over fakes. Viewer logic:
`node --test hosting/share-core.test.mjs`. Thirteen deliberate breakages (no throttle,
stale fixes published, expiry ignored, a second GPS subscription, deletion skipping
shares and others) were each caught by a test.

**On the API 36 emulator and in a real browser**, with the unmodified app, the Firebase
emulators running the real rules, the viewer served locally with `firebase.json`'s
headers, real map tiles and simulated movement:

| Check | Result |
|---|---|
| Public read with no account | `200`; no uid, email, name or journey id in the document |
| Listing shares or route chunks | `403` |
| Token in the viewer server's log, or Android's | Never |
| Offline 2.5 minutes while moving | App: "aren't getting through". Viewer: "Not up to date" after 90 s. Back online: straight to the latest position, then every 15 s. No backlog |
| Standing still | No new position; the update time still moves |
| Stopped | `403`, document gone, viewer "has ended", GPS released |
| Journey finished | "Journey finished", position removed, link cut to 10 minutes |
| Sign-out | `403`, journey kept, GPS released |
| Account deleted | `403`; share, record, journeys, profile and user all gone |
| Link, app closed, signed out | Opens the recipient view; back goes to Welcome |
| Android location requests | One, with or without the map or a share |
| Arabic RTL dark | Start, manage and recipient screens |

**On the live project** (2026-11-05): the viewer and its headers are served, the deployed
rules read back identical to the repo, and a signed-out list, an unknown token and a
private path are each refused.

**Not tested:** a real share on the live project, a real phone, Android verifying the link, a share reaching
`expiresAt` on a device (the rules test covers refusal), iOS.

## 11. Limitations

- **Expired documents stay stored** if the phone never returns, unreadable but not
  deleted. A TTL policy on `expiresAt` could remove them, within about a day, though it
  does not delete the `route` subcollection, and Firebase's page does not say whether
  it needs Blaze. Not configured.
- **A recipient's open listener** in the app gets no event at expiry, so the app ends the
  view by its own clock. The rules refuse any new read.
- **`expiresAt` comes from the phone.** A phone clock badly behind or ahead is refused or
  gets a shorter share; the rules bound it, they do not correct it.
- **Rules cannot rate-limit.** A modified client could write to its own share as fast as
  it likes, which costs that project's quota. App Check is the mitigation, and is not on.
  Nor can they count shares per account: one at a time is enforced by the app only.
- **A swiped-away app stops publishing**, as it stops recording. Android may also kill it.
  The recipient sees the position go stale, and nothing explains why.
- **Android:** the foreground notice is the recording's service; sharing with no journey
  says "SafeRide is sharing your location". Started during a share, a recording keeps
  that notice until the share ends.
- **A finished journey's link** stays readable for its 10 minutes after sign-out: the route
  and the words, no position.
