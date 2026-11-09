# SafeRide — trusted contacts and connections (Batch 17)

Two SafeRide accounts can connect through a private invite. This page is the
design, the security model, what a connection allows, and what stays
unavailable on the Spark plan.

**A connection opens nothing.** It shows each person the other's name. It gives
no access to location, journeys, routes or safety information, and nobody is
alerted through it. Location stays a separate, voluntary link (Batch 16).

**State:** `firestore.rules` and `hosting/c.html` were deployed on 2026-11-05; the
live rules read back identical to the repository, and signed-out reads and writes
of both collections are refused. Everything in §9 ran on the Firebase emulators; no
real invite has run on the live project. Should either ever be missing, the app
says "Not available yet" and makes no link.

## 1. Two things called trusted contacts

| | Saved number | Connection |
|---|---|---|
| What it is | A number the user keeps for themselves | A link between two SafeRide accounts |
| Stored at | `users/{uid}/contacts` | `users/{uid}/connections` |
| The other person knows | No | Yes: they accepted it |
| Verified | Never | The account exists; the name is whatever its owner typed |
| Made by | The user alone | An invite one person sends and the other accepts |

Both are on the Trusted Contacts screen, in separate sections.

## 2. Data model

**The invite: `connectionInvites/{token}`.** Top level, because the person
accepting has no way into the inviter's own paths.

| Field | |
|---|---|
| id | The token: 256 random bits from `Random.secure`, base64url, 43 characters (`BearerToken`) |
| `inviterUid` | Who made it |
| `inviterName` | Copied from their profile; the rules check that it is |
| `status` | `pending`, then `accepted`. Expired is not stored: see §3 |
| `createdAt`, `expiresAt` | Server time; 72 hours later (rules allow 73, for a phone's clock) |
| `acceptedBy`, `acceptedAt` | Set by the acceptance |

**The relationship: `users/{ownerUid}/connections/{contactUid}`.** One record per
side. The id is the other account, so a pair exists once. Each side is separate so
a nickname stays its owner's: rules cannot hide a field from someone who can read
the document.

| Field | |
|---|---|
| `ownerUid`, `contactUid` | Whose record, and who it is about |
| `contactName` | The other person's name at the time. It does not follow a rename |
| `status` | `accepted` or `revoked` |
| `inviteId` | The invite's token: the same on both sides, and what ties them together |
| `createdAt` | When the invite was made |
| `acceptedAt` | Server time of the acceptance |
| `nickname` | Optional, the owner's own word; the other side never sees it |
| `permissions` | `{safetyAlerts: false}`; the rules refuse anything else (§5) |
| `revokedAt`, `revokedBy` | When and by whom it ended |

No email, phone number or other profile field is copied.

## 3. Invitation lifecycle

```
              ┌──────────── expires (72 h, by the server's clock) ──► expired
 created ──► pending ──── accepted, once, by someone else ──► accepted ──► revoked
              └──────────── cancelled by the inviter ──► gone
```

`ConnectionStatus.canMoveTo` holds this. Coming back after `revoked` is not a move:
it takes a new invite, and starts over with no nickname.

1. **Invite.** The app reads the profile from the server, checks the invite page is
   live (`ConnectionLinkCheck`), then writes the invite in a transaction.
2. **Send.** Copy, or the phone's share sheet. The link is
   `https://saferide-a9d9f.web.app/c#<token>`; a browser never sends what follows
   `#` to a server or in a Referer.
3. **Open.** The link opens the app (Android App Links) or `hosting/c.html`, which
   reads nothing and says to paste it in the app under "I have an invite".
4. **Preview.** A signed-in account reads the invite by token and sees who sent it,
   what accepting means, and that names are not verified. Nothing is accepted by
   opening it.
5. **Accept.** One transaction writes the invite and both records.
6. **Live.** Both lists follow a live query, so the inviter sees it as it happens.

Expiring needs no write. A pending invite past its time simply is expired: the
rules refuse it by the server's clock, and `statusAt` shows it as Expired.

Limits, in the app because rules cannot count: 5 invites waiting, 20 people
connected. A used invite is deleted by the inviter's next invite.

## 4. Security Rules

The rules are the boundary; every check in the app only gives a better message.

| Requirement | How the rules enforce it |
|---|---|
| Signed-out access | Nothing here is readable or writable without `signedIn()` |
| Enumeration | `get` needs the token; `list` is only a query for one's own invites |
| A closed invite says nothing | Only the inviter and the acceptor can read one that is used or expired |
| Posing as someone else | `inviterName` must equal the inviter's profile; each side's `contactName` must equal the other's real name |
| Accepting once | The update needs `status == 'pending'`; the second writer is refused |
| Expiry | The update and the read need `expiresAt > request.time` |
| One's own invite | `request.auth.uid != inviterUid` |
| Inviter deleted | The update needs `exists(users/{inviterUid})` |
| Connecting two other accounts | `acceptedBy` must be the writer, and the writer must be one of the pair |
| A half-made connection | The invite's update needs both records `existsAfter`; each record needs the invite accepted, by this write, `getAfter` |
| Replaying an old invite | A record needs `invite.acceptedAt == request.time`, which only the accepting write can satisfy |
| Reactivating | `revoked → accepted` needs a new acceptance; a plain write is refused |
| Changing another account's record | The other side can do one thing: `accepted → revoked`, stamped with its own uid and the server's time. It cannot read the record |
| Leaving the other side connected | A record can be deleted only once it is revoked, or the other side is |
| Granting a permission | `permissions` must equal `{safetyAlerts: false}` |

**Nothing is privileged, and no client can do what a backend would.** Accepting is
the one time an account writes into another's path, and only under every condition
above. No rule anywhere else reads a connection (`rules.test.mjs` checks the file
itself), so becoming connected cannot widen access to anything.

**What a token holder sees:** the inviter's name and account id, while the invite
is open. Accepting needs the id, and without a backend it cannot be hidden. An
account id alone opens nothing.

## 5. Permission model

`ConnectionAccess.allows` is the one answer for every later feature:

| Asked for | Answer |
|---|---|
| Live location, journeys, recorded routes, emergency information | Always no, whatever is stored |
| Safety alerts | Only if connected **and** allowed **and** `AppFeatures.contactAlerts`. Off today, and the rules refuse storing it as allowed |

The Manage screen draws this: nothing on it is a switch, because nothing can be
turned on.

## 6. Ending a connection

Either person can. One transaction ends both records, immediately; both keep the
date and who ended it, and it moves to Ended, where each person can clear it.

**It is not the same as stopping a location link.** A Batch 16 link is a bearer link
that anyone holding it can open, whoever they are, and it keeps running. Ending a
connection never touches it, and stopping a link never touches a connection; the
confirmation says so. Neither can undo what was already seen, copied or saved, and
the confirmation says that too.

Deleting an account (`FirestoreConnectionRepository.erase`) ends each connection on
the other person's side, then deletes this account's records and invites. A
connection that was ended leaves its record on the other side until they clear it,
with the name in it.

## 7. Offline and uncertain results

Everything that changes who is connected is a **transaction**, because a plain
write made offline waits in the phone's queue and looks done. Nothing is queued;
nothing reads as done until the server said so. A nickname is the exception: it
only changes the owner's own view, so it may wait for a signal.

**Transactions here only write.** The checks are plain reads from the server first,
and the rules decide regardless. This came from a real run, not from reasoning:

- with reads inside the transaction, the first accept after being offline committed
  on the server, and the SDK ran a second attempt anyway, which found the invite
  accepted;
- a failure thrown inside a transaction can lose to the plugin's own, so the same
  case surfaced as either "already connected" or a lost connection. The connection
  existed both times, and the app said otherwise.

So `_commit` also never believes a failure on its own: it asks the server whether
the write landed, and only then calls it a failure. Offline, Firestore reports a
transaction as `unknown`, not `unavailable`, so only `permission-denied` and
`not-found` count as a refusal and anything else as a lost connection. The message
says the result could not be confirmed, because that is what is known.

| Case | What the person sees |
|---|---|
| No internet | "Couldn't reach SafeRide"; the offer stays, nothing is sent later |
| Malformed link | "That isn't an invite" |
| Expired, used, cancelled, inviter deleted | "This invite can't be used": one message, so a stranger with a token learns nothing |
| Already connected | "You're already connected" |
| One's own invite | "This is your own invite" |
| Signed out | "Sign in first", then open the link again |
| Two people at once | One connects; the other is refused by the rules |
| Rules or page not deployed | "Not available yet", and no link is made |
| The list is the phone's copy | "You're offline, so this list may be out of date" |

## 8. What stays unavailable on Spark

Cloud Functions cannot run, so:

- **No alerts.** `AppFeatures.contactAlerts` stays off. Nobody is notified of
  anything, including a new invite or the end of a connection, except by the list
  changing when they open it.
- **No clean-up by time.** An expired invite stays until the inviter clears it or
  deletes the account. It cannot be used.
- **No hiding the inviter's id** from a token holder (§4).
- **No server-side limits.** Rules cannot count, so a modified client could exceed
  5 and 20 for its own account. It cannot affect anyone who did not accept.
- **An account deleted outside the app** (the Firebase console) leaves the other
  side `accepted`. Removing it then ends this side alone.
- **A waiting invite survives removing someone.** Whoever holds it can still accept
  it, so a person removed could reconnect with an older invite until it is
  cancelled or expires. The Invitations section shows what is still out.
- **Names are what people typed.** A connection proves an account exists and
  accepted; it does not prove who is behind it. The screen says so.

**Batch 13's invites** (`createContactInvite`, `contactLinks`, the eight-character
code) are separate and stay behind `AppFeatures.contactAlerts`, untouched. They
link a saved number to an account for alerts and need Cloud Functions. If a backend
ever exists, alerts should move onto connections, with `ConnectionAccess` as the one
check, and that flow should go.

## 9. Testing

```bash
flutter test test/features/safety
cd test/firestore_rules && npm test   # Firebase CLI + JDK 21
```

- `connection_models_test`: states, expiry, links, the permission evaluator.
- `firestore_connection_repository_test`: every path, offline, lost answers,
  account isolation, deletion.
- `connection_cubits_test`: the list, double taps, accepting.
- `connections_screens_test`: the real router and screens, English and Arabic.
- `rules.test.mjs`, "connections between accounts": reads, writes, forged fields,
  expiry, reuse, two real clients racing, revocation, and that a connection opens
  nothing.

**Run on the API 36 emulator** (the app on the Auth and Firestore emulators with the
real rules, and the pages served with the real headers; three local test accounts):
an invite opened cold and signed out; creating, sharing and copying one; one's own
link; a used link; an expired link; pasting; accepting online; accepting in airplane
mode, with nothing written and nothing sent after reconnecting; accepting again
online; removing, on both records; reconnecting by a new invite; a nickname on one
side only; a connection ended from elsewhere appearing live; clearing; Arabic RTL
dark; account deletion, with the other side ended and nothing left behind; the
invite page in a browser with no console errors.

**Not run:** the live project, App Links verification, a real phone, any iOS device,
two phones at once (the second side was written directly, and the race between two
clients ran in the rules tests only).
