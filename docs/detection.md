# SafeRide — movement detection (Batches 11, 12 and 18)

What SafeRide notices during a journey in progress, how sure it is, what it
ignores, and what it cannot know. Batch 11 built it, Batch 12 added the
15-second safety check, and Batch 18 reduced false positives.

**GPS sees the consequences of an event, never the event.** A phone gives one
position and one speed every 2 s, each a few metres or a few km/h off; a
collision lasts a fraction of a second. What GPS can show is a vehicle that
went from driving to standing still very fast, and then stayed. A hard brake at
a red light shows exactly that too. **Nothing here detects or confirms an
accident**, and no copy may say it does: SafeRide "noticed unusual movement".

## 1. The pipeline

```
phone GPS ──► JourneyTracker (the one subscription, a fix every 2 s, a tick every 5 s)
                 ├─► route: RouteFilter → TrackPoint, distance, chunks to the account
                 └─► IncidentMonitor (TrackingObserver: every fix, tick, interruption)
                        └─► IncidentDetectionEngine (pure; one per journey)
                               └─► IncidentConfidenceRules (pure)
                        ◄── signals ──┘
                     IncidentRepository (on the phone) ──► SafetyCheckService ("Are you okay?")
```

No other location subscription, timer or background service exists for
detection. The engine keeps a few seconds of readings; nothing it does writes
to Firestore.

## 2. What is noticed

| Event | When | At most |
|---|---|---|
| Sudden deceleration | A drop from driving speed to standing still between two fixes, then staying put | high |
| Prolonged stop | Five minutes still, after the journey had set off | high, only after a real deceleration |
| Tracking interrupted | Permission removed, services off, no usable fix for 60 s, the app suspended or closed | always low |

Only a movement event of medium or high confidence asks "Are you okay?"
(`SafetyCheckEligibility`). An interruption never asks: missing data is not
evidence. A timeout means the user did not answer, nothing more.

### Sudden deceleration

1. **The drop:** two trusted speed readings at most 4 s apart, from ≥ 30 km/h to
   ≤ 5 km/h, at ≥ 4 m/s², with the positions agreeing with the speeds.
2. **Staying put:** after the drop, the vehicle must stay within 15 m (or twice
   the fix's accuracy). Two fixes in a row further away, two readings in a row
   above 3.6 km/h (crawling with a queue), or one reading above 10 km/h (driving
   on) cancels it. A minute with no fix at all drops it.
3. **When it is reported:** at the first fix, 15 s or more after the drop, on
   which every high condition holds; otherwise at the first fix 45 s or more
   after it, as medium or low. With a fix every 2 s that is 16 s or 46 s. With
   sparser fixes high waits for its fifth fix (fixes 6 s apart: 30 s), and
   fixes more than 6 s apart are never high.

   **Magnitude matters for high:** 7 m/s² over one 2-s interval means a drop of
   at least 14 m/s — from about 51 km/h or more to a standstill. A stop from
   50 km/h measures 6.94 m/s²: at most medium, reported at 46 s.

### Prolonged stop

1. **Set off first:** 200 m from the start, or driving speed, each seen in two
   fixes in a row.
2. **Still:** within 30 m (or twice the accuracy) at ≤ 3.6 km/h for 5 minutes.
   A gap of more than 60 s between fixes starts the count again.
3. **Leaving:** two fixes in a row more than 50 m away, or two readings in a
   row at ≥ 10 km/h.

## 3. Thresholds, before and after Batch 18

All in `IncidentDetectionConfig`, each with its reasoning in the code. They are
engineering starting points, not validated accident-detection parameters.

| Threshold | Before | Batch 18 | Why |
|---|---|---|---|
| Drop: speeds, window, ≥ 4 m/s², position check | — | unchanged | Ordinary braking (1.5–3 m/s²) never reaches it at 2 s sampling |
| Stay put after the drop | ≤ 10 km/h for 15 s, one fix enough | within 15 m; no crawling; ≥ 5 fixes ≤ 6 s apart for high | A queue crawls; one fix 15 s later is not evidence |
| Report a drop | 15 s, any confidence | 15 s if high; else 45 s | A hard stop for a light shows the same GPS drop. The light turns green |
| "No fixes" timeout | 30 s from the drop | 30 s from the last fix | The old count would have cancelled every wait over 30 s |
| Has set off | one fix ≥ 200 m away, or one driving reading | two in a row | One GPS jump or one wild speed armed the 5-minute stop |
| Leaving a stop | one fix > 50 m away | two in a row | One jump ended an open stop and restarted its count |
| Speed error reported as 0 or less | "precise" | unknown | Some phones mean "not measured" |
| Fixes reaching the engine | any order | only newer than the last | A late or repeated fix moved its clock back |
| Stop after a deceleration → high | any deceleration | medium or high only | A low one is one anomalous reading |
| Creeping during a stop (two fixes in a row) | ignored | twice → low | A queue moves; someone who cannot, does not |
| Stop at the planned destination (150 m + accuracy) | medium | low | It has arrived |
| "I'm fine" given at a place | asked again by the next event | nothing new there until it moves on | The user's answer stands |

Every other value (accuracy limits 20 / 25 / 15 / 10 m, fix age 10 s, speed
error 2 / 1 m/s, 5 minutes, 30 m, 60 s gaps, 60 s signal loss, 30 s suspension)
is unchanged.

## 4. Confidence

`IncidentConfidenceRules` — pure functions of the evidence, tested one condition
at a time (`incident_confidence_test`). A threshold crossed alone is never high.

**Sudden deceleration**

- **High:** ≥ 7 m/s²; at least two driving readings in the 15 s before; both
  fixes of the drop within 10 m; both speed errors reported and ≤ 1 m/s; and
  since the drop at least 5 fixes, none more than 6 s apart. Reported at 15 s.
- **Medium:** ≥ 5.5 m/s²; two driving readings before; both fixes within 15 m;
  still for 45 s with no gap over 30 s.
- **Low:** anything else that got that far.

**Prolonged stop**

- **Low:** fixes worse than 15 m or more than 30 s apart; or it crept forward
  twice; or it is at the planned destination.
- **High:** otherwise, when it began within 60 s of a medium or high sudden
  deceleration.
- **Medium:** otherwise.

**Tracking interrupted:** always low.

## 5. GPS validation

The engine and the route each judge every fix for themselves.

| Problem | Engine | Route (`RouteFilter`, `JourneyTracker`) |
|---|---|---|
| Not a position (NaN, out of range, 0,0, no accuracy) | ignored | not stored |
| Poor accuracy | > 25 m ignored; > 20 m no speed | > 50 m not stored; > 25 m "weak signal" |
| Stale | > 10 s old ignored | > 30 s old not stored |
| From the future | > 10 s ahead ignored | > 5 min ahead not stored |
| Duplicate timestamp, out of order | ignored | not stored; never moves "where the phone is" or the speed back |
| Coordinate jump | needs two fixes in a row to change its mind | **measured from when the phone was last seen at the last point**, not from that point's time |
| A jump that stays | — | three agreeing jumps in a row: a new segment, no distance across |
| Unrealistic speed change | the drop's positions must agree with its speeds | speed only from the phone, error ≤ 3 m/s, smoothed |
| Long gap | 60 s restarts a stop; 60 s is signal loss | 2 minutes starts a new segment (unchanged) |
| Location provider failure | — | not "permission removed": retried after 5 s, doubling to a minute; detection reports a lost signal if it lasts |

Before Batch 18, a single reflection after standing still for a minute was
accepted (the minute counted as travel time), added up to a kilometre, and made
the real fixes after it look like jumps until about as much again had been
added. Now that glitch is a jump, and nothing is added.

## 6. Lifecycle and recovery

| Situation | What happens |
|---|---|
| GPS lost for a while | Under 60 s, nothing. Then a low "signal lost", cleared when fixes return; a stop's count restarts |
| Permission removed / services off | A low interruption with its cause; any drop waiting to be confirmed is dropped |
| Background (Android) | The foreground service keeps the process, the fixes and the engine running |
| Suspended | Ticks stop; on return, a low "app suspended"; nothing waiting is concluded |
| Process killed | Nothing runs. On reopening, the recording resumes as a new segment and a new engine starts; over 60 s since the last fix is a low "app closed" |
| Reopened while still parked | A new engine needs the journey to set off before a stop counts, so a parked vehicle is never asked about twice |
| Dismissed ("I'm fine", "I'm safe") | Final for that event; nothing new at that place until the vehicle moves on |
| Resolved (moved on, tracking back, journey ended) | Final |
| No answer | `escalationReady` — no answer, not an accident. A later event may ask again |
| A new journey | A fresh engine: nothing carries over |

No new state is persisted for recovery. What survives a restart is what already
did: the route on the phone, the incidents and checks on the phone, and the
safety check's deadline.

## 7. What is still not detected, or still asked

- **An emergency stop held 15 s with precise data asks.** It shows exactly what a
  collision shows; asking is the point. A firm stop for a red light without
  precise speed errors waits 45 s instead.
- **A low-speed collision** (under 30 km/h) is never a sudden deceleration. Only
  a stop that lasts 5 minutes is noticed.
- **A collision that keeps moving** (pushed along, or driven on) is not noticed.
- **A stop under 5 minutes, or under 45 s after a weaker drop,** asks nothing.
- **A vehicle that stops near its destination** is low: a collision at the
  destination is not asked about.
- **A phone thrown or switched off** gives no fixes: only "signal lost", low.
- **One fix every 2 s** can miss a short event, and averages a very hard stop
  down.
- **Android:** detection runs only while the app process lives; swiping the app
  away ends it until it is opened. **iOS:** the system may suspend the app.
- **Low-confidence events** are kept on the phone and never shown or asked.

## 8. Testing

```bash
flutter test test/features/journeys
```

- `detection_scenarios_test` replays 23 scenarios and more through the real
  engine, monitor and safety check (`test/features/journeys/simulation/gps_script.dart`
  builds the GPS: driving, braking, drops, holds, crawling, turns, gaps,
  suspensions, jumps, stale, repeated and late fixes, poor accuracy, missing
  speed). Each says what must and must not happen.
- `incident_confidence_test`: every confidence rule, one condition at a time.
- `detection_timing_test`: when a stop is reported (16 s high, 46 s medium, the
  five-fix rule with sparse fixes), and that the 15-second check starts at the
  moment detection reports — never before.
- `incident_detection_engine_test`, `incident_monitor_test`, `route_math_test`,
  `journey_tracker_test` (GPS validation group), `safety_check_service_test`.

**Run on the API 36 emulator** (debug build of the unmodified app on the
Firebase emulators, simulated GPS with speed): a hard stop from 50 km/h held
still asked nothing at 12 s and 33 s and asked at about 50 s — medium, because
13.9 → 0 m/s in 2 s is 6.94 m/s², under the 7.0 high needs (the stored record:
"6.9 m/s², then stayed put for 46 s over 23 fixes"); whether the emulator
reported a speed error is not recorded, and would not have changed this.
`detection_timing_test` replays that run second by second; left unanswered, it said "No answer recorded";
the 5-minute stop then asked, as high, and "I'm safe" closed it; the app killed
and reopened while parked asked nothing in 7 minutes; a second hard stop
answered "I'm safe" was not followed by a second question at the 5-minute mark;
parked with GPS wobble, the distance did not grow.

## 9. Needs a real phone

Nothing here has run on a phone or in a vehicle. Before anyone relies on it:

- Real braking: city stops, amber-light stops, emergency stops, speed bumps,
  roundabouts and sharp turns — counting how often each asks.
- Stop-and-go traffic and long red lights.
- Parking garages, tunnels and urban canyons: accuracy, jumps, signal loss.
- Phones that report no speed error, or report 0 for it.
- The app in the background for a whole journey, the screen off, battery
  savers and OEM process killers.
- iOS in every case above (no Mac here).
- Tuning: thresholds should change only with recorded journeys, replayed
  through `GpsScript`-style tests.
