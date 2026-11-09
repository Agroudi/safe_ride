# SafeRide — emergency numbers, calling, texting and location (Batches 20, 21)

How SafeRide helps someone reach emergency services themselves, and what it
cannot do. `CLAUDE.md` §16 holds the decisions; Batch 10 built the dataset and
the country choice; Batch 19 the escalation that leads to Get help
(`docs/escalation.md` §11).

> **SafeRide never calls anyone.** Call opens the phone app with the number
> filled in. The user presses call, or cancels. SafeRide cannot see whether the
> call connects or is answered, cannot dispatch anyone, and sends no location
> to any emergency service.

## 1. The directory

One directory, shown in two places: **Emergency information** (Safety tab, any
time, no incident needed) and **Get help** (after an unanswered safety check,
or any time). Both use `EmergencyDirectorySection` over `EmergencyCubit`; there
is no second list.

- **Country:** the one the user chose (`core/country/`, Batch 10), never
  guessed from the SIM, the language or GPS. No country: the screen asks for
  one and shows no numbers. A country without checked numbers: none shown.
- **Order** (`EmergencyDirectory`, pure Dart): a number that answers only in
  some regions first, naming them; then by what happened — ambulance / medical
  emergency, police, civil defence / fire and rescue, traffic / road
  accidents, road security. A number shared by several services is one tile
  naming them all (Kuwait's 112).
- **Missing services are said, never filled in:** "SafeRide has no checked
  number of its own for traffic accidents in Kuwait. If anyone is hurt or in
  danger, call 112." (the country's ambulance number).
- **Offline:** the dataset is bundled (`assets/data/emergency_services.json`)
  and validated on load; no Firestore read, no network.

## 2. The numbers, re-checked 2026-11-08

Every number was checked against an official page readable on that day. Two
Saudi regional statements are cited through newspapers that report them; the
numbers themselves are in the national numbering plan.

| Country | Number | Services | Scope | Source |
|---|---|---|---|---|
| SA | 911 | every emergency | **Riyadh, Makkah, Madinah, Eastern Province only** | CST numbering plan; Okaz, 6 Nov 2026, reporting the Ministry of Interior |
| SA | 997 | ambulance (Saudi Red Crescent) | national | CST numbering plan |
| SA | 999 | police | the ministry gives it for regions outside 911 | CST; Okaz (above) |
| SA | 998 | civil defence | outside the 911 regions; in them, call 911 | CST; Asharq Al-Awsat, 14 Sep 2026, reporting Civil Defense |
| SA | 993 | traffic | national | CST |
| SA | 996 | road security | national | CST |
| AE | 999 / 998 / 997 | police / ambulance / civil defence | every emirate | u.ae |
| KW | 112 | police, ambulance, fire | national | Ministry of Interior |
| QA | 999 | police, fire, medical | national | Ministry of Interior; Hamad Medical Corporation |
| BH | 999 | ambulance, civil defence, police | national | bahrain.bh |
| BH | 199 | traffic accidents | national | bahrain.bh |
| OM | 9999 | emergency (police, ambulance, fire) | national | Royal Oman Police; gov.om; CDAA |
| EG | 122 / 123 / 180 | police / ambulance / civil protection | national | Ministry of Interior; State Information Service |
| EG | 01221110000 | traffic accidents | national; an 11-digit mobile number, not a short code | Ministry of Interior |

Changes in Batch 20: Saudi Arabia's 911 is now **structurally regional**
(`"scope": "regional"`, with its regions in a note); 999 says where the
ministry assigns it; three Saudi Press Agency links that showed unrelated
headlines were replaced; Qatar's source points at the page that lists the
numbers; every country is dated 2026-11-08. No number was added or removed.

**Left out, unverified:** Saudi Arabia's 112 (only a carrier lists it), Egypt's
112 (press only), the UAE's and Bahrain's 112, Oman's old 999.

**Official but not listed** (one number per service in this schema): Oman's
Civil Defence and Ambulance operations centre 24343666 (a landline, beside
9999); Qatar's 992 for deaf callers (SMS or video). Both are candidates for a
later schema with secondary lines.

**Still to verify:** whether 999 and 998 still connect inside the four 911
regions (no official statement found); when 911 extends to other regions;
whether road accidents in the 911 regions go to 911 rather than 993. Egypt's
ambulance authority site did not load; 123 rests on the State Information
Service (May 2025).

## 3. Regions

SafeRide cannot tell which region the user is in: GPS may be old, rough, or
near a boundary, and a wrong guess dials the wrong number. **It never picks a
regional number from GPS.** The user knows where they are, so the regional
number comes first with its regions named, and the national numbers follow.
`EmergencyDirectory.numberFor` never returns a regional number.

## 4. Calling

Six things happen between a tap and help arriving. SafeRide sees the first two.

| # | Step | Who sees it |
|---|---|---|
| 1 | The number is prepared (`DialNumber.prepare`: spaces, dashes, dots and brackets removed; then `+` and 2–15 digits) | SafeRide |
| 2 | The phone app opens with it (`DialOutcome.opened`) | SafeRide |
| 3 | The user presses call — or cancels | the phone app |
| 4 | The system logs the call | the system; SafeRide reads no phone state |
| 5 | The call connects | the network |
| 6 | A service answers and responds | the service |

`CallLauncher` (app-wide) is the one way in: it refuses an empty or malformed
number, lets one launch through at a time, and ignores a second tap within
`AppDurations.dialCooldown` (2 s) of the phone app opening. A failed launch can
be retried at once. Nothing about a call is stored. `PhoneDialer`
(`UrlLauncherPhoneDialer`) is the platform end; tests use fakes and harmless
numbers only.

Outcomes and what the user is told:

| Outcome | Notice |
|---|---|
| `opened` | "Your phone app opened… Press call in your phone app. SafeRide can't see whether the call was made." |
| `noDialer` | "This device can't make calls. Dial {number} from a phone." |
| `failed` | "Your phone app didn't open. Dial {number} yourself." |
| `invalidNumber` | "This number can't be dialled from SafeRide. Dial {number} yourself in your phone app." |

The number stays on screen, large, in every case.

**Fixed in this batch:** a saved contact typed with spaces ("+966 55 …", which
the form allows) used to be refused as invalid; it is now prepared first.

### Android

- `tel:` through `url_launcher` is an `ACTION_VIEW` that opens the dialer with
  the number filled in — the user-confirmed flow. **No `CALL_PHONE`
  permission**: SafeRide never places a call, and Android sends a third-party
  call to an emergency number to the dialer anyway.
- `<queries>` (`VIEW` + `tel:`) lets `canLaunchUrl` answer on Android 11+.
- Dual SIM: the dialer asks which SIM. No SIM or no service: whether an
  emergency call still goes through is the phone's and network's business.
- Not verified: OEM dialers, a real call, a device with no dialer.

### iOS (nothing tested: no Mac here)

- `tel:` shows the system's own "Call …?" prompt with Call and Cancel; the
  user returns to SafeRide after. `LSApplicationQueriesSchemes: tel` lets
  `canOpenURL` answer; an iPad or iPod reports `noDialer`.
- No API tells an app whether the call connected (SafeRide uses no CallKit
  observer, and would not claim more if it did).

## 5. Where you are

`EmergencyLocationCard` on both screens, over `EmergencyLocationCubit` and the
core `EmergencyPositionReader`, implemented by `TrackerPositionReader` over
`JourneyTracker` — still the one source of GPS.

- On open it shows only what is known: the recording's newest fix. **No new
  reading without a tap** ("Find my location" / "Update my location"), and
  **never a permission prompt**: not allowed, approximate only, or location
  off are each said, and Find is off without permission.
- **Current** only within 20 s of the fix (the maps' rule); then **Last known**
  with its age; past 5 minutes a warning that the user may be far from there.
  The age is re-read every 5 s, so a reading never stays "current".
- Accuracy: "Accurate to about N m"; over 100 m "Rough: could be N m off or
  more"; unknown said. Approximate-only permission is said.
- Coordinates in Latin digits, five decimals, left to right, selectable, with
  Copy. A 0,0 or impossible fix is never shown.
- The journey in progress: "Journey in progress to {destination}", in the
  user's own words.
- The card says SafeRide does not send the location to emergency services and
  that they cannot see it. Nothing is sent, stored or logged; Batch 16 sharing
  is only offered on Get help, as a link to its own screen.

## 6. Guidance

"Which service?" (ambulance, police, civil defence — by what is happening, no
diagnosis) and "On the call" (say where you are first; stay on the line;
SafeRide can't make sure they get your location; don't rely on SafeRide alone).
Arabic and English.

## 7. Get help

With an escalation open: "I'm okay" first, then the directory (with the
country and Change), what Call does, Emergency information, where you are,
Share this journey (Batch 16's screen; nothing shared until started there), and
the user's people (Batch 17). Without one: the same, minus "I'm okay" and
sharing. Emergency numbers never wait for an incident.

## 8. What SafeRide cannot guarantee

That the phone app opens; that a call is placed, connects or is answered; that
a service responds or arrives; that a service learns the user's location; that
a regional number works outside its regions; that a dataset entry is still
current after its check date. Every screen says the user must place the call
and tell the operator where they are.

## 9. Physical-device tests still needed

Never call a real emergency number in a test.

1. Call on a real Android phone (Samsung, Pixel, Xiaomi) and an iPhone, with a
   **non-emergency test number**: the dialer opens with it, cancel returns.
2. Dual SIM, no SIM, airplane mode, a tablet without telephony.
3. "Find my location" outdoors, indoors and with approximate permission; the
   age and accuracy against reality.
4. Arabic RTL and 2× text on a small screen.
5. TalkBack and VoiceOver on the directory and the location card.

## 10. Calling and texting trusted contacts (Batch 21)

**Only numbers the user saved themselves can be called or texted.** A
connection (Batch 17) shares a name and nothing else — no phone number — and
its rules and `ConnectionAccess` are unchanged. A connected person is listed
by name with "a connection doesn't share their phone number"; to call or text
them, the user saves their number. Ended connections and invitations offer
nothing.

Where: Get help (people, after the emergency directory, where you are and
sharing) and the Trusted Contacts list (under each saved number). Each saved
number shows, before anyone taps, whether it can be used
(`ContactReach`: available · missing · invalid — the form allows up to 20
characters, the phone app 15 digits).

| Action | What happens | What SafeRide knows |
|---|---|---|
| Call | The phone app opens with the number (§4) | It opened |
| Message, Get help | The messaging app opens to the number with "I may need assistance. Please contact me as soon as possible." in the app's language, editable | It opened |
| Message, Trusted Contacts | The messaging app opens to the number, empty | It opened |

- **One launcher:** `CallLauncher` does both — the same number preparation,
  one launch at a time, and the cooldown shared across Call and Message.
  `MessageComposer` (`UrlLauncherMessageComposer`) is the platform end.
- **Nothing is sent by SafeRide:** no `SEND_SMS`, `READ_SMS`, `CALL_PHONE` or
  `READ_PHONE_STATE` (`platform_config_test` fails the build on any of
  them). No message, number or outcome is stored or logged.
- **No location in a message.** Get help says so, and that the way to send
  where you are is Share this journey (Batch 16) and its link, sent by the
  user. The share screen's own share sheet can send that link by text.
- Outcomes: `opened` ("send it yourself… SafeRide can't see whether it was
  sent"), `noMessaging` (a device that cannot text), `failed`,
  `invalidNumber`. There is no "sent" or "delivered".
- **Android:** `sms:<number>?body=<text>` (ACTION_VIEW) opens the default
  messaging app; `<queries>` declares `sms` so `canLaunchUrl` can answer.
  Verified on the emulator with Google Messages.
- **iOS** (not tested, no Mac): `sms:<number>&body=<text>` opens Messages;
  `LSApplicationQueriesSchemes` lists `sms`. An iPad without Messages over
  SMS reports `noMessaging` or opens iMessage, which the user controls.

Physical-device tests: Call and Message to a **test** number on Android
(Samsung, Pixel, Xiaomi — default messaging apps differ in how they read the
body) and an iPhone; a dual-SIM phone; a tablet; Arabic text arriving intact.
