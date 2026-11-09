# SafeRide — maps, search and routing (Batch 15)

How the map works, which providers it uses and why, what they cost, and what
they learn. Providers' terms were read on 2026-11-04; **re-check them before a
release**, as every one reserves the right to change.

## 1. Providers

Nothing here needs a key, an account or a payment.

| Job | Provider | Limits | Commercial use | Guarantee |
|---|---|---|---|---|
| Rendering | `flutter_map` 8 + `vector_map_tiles` 9 beta | n/a | BSD-3 | n/a |
| Tiles | [OpenFreeMap](https://openfreemap.org/) (OpenStreetMap data) | None stated on views or requests | Allowed | None. Donation-funded, may stop without notice |
| Search | [Photon](https://github.com/komoot/photon), komoot's public server | "Reasonable", no figure; heavy use is throttled or banned | Unstated | None |
| Routing | [OSRM demo server](https://github.com/Project-OSRM/osrm-backend/wiki/Demo-server), run by FOSSGIS | At most 1 request a second; high-traffic use generally not permitted | **"Reasonable, non-commercial"**; FOSSGIS allows it only where it is not a substantial part of the offering | None; permission can be revoked without notice |

**Cost today: nothing.** All three run on donations and goodwill, so an app with
real users should not rely on them forever (§6).

### Why these

- **Tiles.** OpenStreetMap's own raster tiles have no dark style, the policy
  gives "no SLA or guarantee", and commercial services may lose access. CARTO's
  dark tiles now need a key. OpenFreeMap has a real dark style with no key, so it
  is the only option that meets the theme requirement without an account.
- **Search.** Nominatim is out: its policy lists client-side autocomplete as
  "strictly forbidden". Photon is built for search as you type.
- **Routing.** The other free services need a key. OSRM needs none, but its
  demo terms are the tightest of the three: see §6.

All three were tried from here for Riyadh, Jeddah, Cairo, Dubai, Abu Dhabi and
Kuwait, and answered correctly, in Arabic where the data has it. Photon has no
Arabic `lang` (only `default`, `en`, `de`, `fr`), so Arabic searches ask for local
names, which are Arabic across the supported countries.

### Staying within fair use

- Search waits 500 ms after typing stops, ignores under 3 characters, aborts the
  older request, and never repeats a query it already has an answer to.
- A dropped pin is named only after it rests for 800 ms.
- A route is asked for only when a place changes, and once per pair. **Never per
  GPS fix.** The live map asks once when it opens.
- Every request names the app: `SafeRide/1.0 (com.saferide.falcon)`.

## 2. Architecture

```
GeocodingRepository  ← PhotonGeocodingRepository
RoutingRepository    ← OsrmRoutingRepository     (all over MapHttp)
MapTileProvider      ← OpenFreeMapTiles
```

Screens and cubits know only the interfaces. To replace a provider, add an
implementation and swap it in `service_locator.dart`. To point at another server
of the same kind, no code is needed:

```bash
flutter build apk --dart-define=MAP_ROUTING_URL=https://routing.example.com
```

`MAP_TILES_URL` and `MAP_GEOCODING_URL` work the same way.

- **`AppMap`** is the one map widget: tiles, credit, offline note. Screens pass
  their own layers.
- **`JourneyMapCubit` has no GPS of its own.** It listens to
  `JourneyTracker.snapshots`, the stream the journey screen already uses, and
  reads stored points through the tracker. For an active journey it also calls
  `JourneyTracker.start`, as the journey screen does: that joins the one recording,
  or starts it if none is running, and never opens a second subscription. It
  writes nothing itself. Incident detection and the safety check do not touch it.
- **`JourneyTracker.locate()`** serves "Use my location": the recording's last fix
  while it is running and under 20 seconds old, else a single one-off reading. An
  older fix is never offered, and none outlives its recording. That reading is the
  only location access outside the tracker's subscription, and it is not a
  subscription. It happens only on the user's tap.
- **Rendering never changes data.** `flutter_map` simplifies long polylines when
  drawing; stored points are untouched.

### Theme

The dark map is a real style. `MapStyleTuner` rewrites the style's paints from
`AppColors` (OpenFreeMap's own dark labels are too dim) before it renders, so
text stays crisp. Light uses the Positron style unchanged.

⚠️ **Each style needs its own `id`.** OpenFreeMap's have none, so both read as
`default`, the tile layer's caches collided, and light mode drew dark tiles.
`MapStyleTuner` sets the ids. Bump its `version` when changing colours.

### Data

Journeys gained optional fields; **existing journeys need no migration**.

| Field | Type |
|---|---|
| `originPlace`, `destinationPlace` | `{name, lat, lng, address?, placeId?}` |
| `plannedDistanceMeters`, `plannedDurationSeconds` | number |

`origin` and `destination` stay the user's own words. A journey with no pins has
none of these fields, and a stored place with bad coordinates reads as no place,
never as a broken journey. Typing over a pinned place removes its pin.

The rules list every journey field, so a new field needs a rules change, deployed
before the version that writes it. These were deployed on 2026-11-04, and they also
accept what older app versions write.

## 3. Estimates

Distance and time come only from the routing provider, always labelled as
estimates. Remaining distance and arrival appear only while the position is
within 150 m of the planned route. Off the route, or with no route, they are
gone, not guessed. Arrival scales the provider's time by what is left; it knows
nothing of today's traffic. **This is not navigation.**

## 4. Offline

Tiles, search and routes need a connection. Without one:

- Recording, the safety check and detection carry on: they never depended on it.
- The live map keeps the recorded route, the position and the pins over a plain
  ground, with a note. Remaining distance and arrival disappear.
- Search says it needs a connection. A pin can still be placed and confirmed, and
  a journey can be planned by typing.
- A failed route says why, keeps the places, and never blocks planning.

Tiles already seen stay in `vector_map_tiles`'s own cache. **Nothing is
prefetched**, and there is no area download.

## 5. Privacy

| Sent to | What | When |
|---|---|---|
| Photon (komoot) | Search text, and the pin's area rounded to about 1 km | While searching |
| Photon | A dropped pin's coordinates, to about 1 m | After it rests |
| OSRM (FOSSGIS, which saves route requests in its server log) | The start and destination, to about 1 m | When both are set, and each time a journey with both opens its map, finished ones too |
| OpenFreeMap (via Cloudflare) | Which tiles, so **the area on screen** | Whenever a map is open |

All of them also receive the phone's IP address, as any server does, and
`SafeRide/1.0 (com.saferide.falcon)`. What they keep: OpenFreeMap's policy says its
access logs hold no IP by default, its error logs may, and logs go after 7 days
(30 in an incident); Cloudflare's own policy was not read. FOSSGIS states no
retention period. Photon's page states nothing about logging, and komoot's privacy
policy was not read.

**During a journey the tile requests follow the map**, so OpenFreeMap can see the
area someone is in while the live map is open, as with any online map. It does not
see who they are or any journey data.

Never sent to any of them: the recorded route, the account, or a user id. No
coordinates are logged. Pins live in the owner's journey under the existing rules.
There are no keys, so nothing can leak. If a provider that needs one is added,
pass it with `--dart-define`, restrict it in the provider's console, and keep it
out of the repository: a key in an app can always be extracted.

## 6. Before a store release

1. **Routing is the blocker.** "Non-commercial" does not fit a commercial app. Run
   OSRM yourself, or use a paid or free-tier provider: a new `RoutingRepository`,
   or `MAP_ROUTING_URL` for a compatible server. Check current prices first;
   anything paid needs the owner's approval. A journey never depends on a route:
   if routing is gone, planning still works and the estimates simply do not show.
   FOSSGIS's terms also ask, of an app: the operator's email easy to find on its
   website and store entries, the service URL not hardcoded (`MAP_ROUTING_URL` is a
   build-time default today), a credit naming OpenStreetMap, ODbL and CC-BY-SA with
   a report-an-error link to `openstreetmap.org/fixthemap` (`MapCredit` says only
   "OSRM"), and a valid Referer where possible (none is sent). Check which still
   apply to any replacement.
2. Photon at scale: self-host, or use a provider with a contract. Its commercial
   use is unstated, and it publishes no limit or privacy terms.
3. Tiles: OpenFreeMap has no SLA. Self-hosting its data is an option.
4. `vector_map_tiles` is a **pre-release** (`9.0.0-beta.13`, pinned exactly), the
   only line that works with `flutter_map` 8. Its last stable release needs
   `flutter_map` 7. Watch it on upgrades, and test on real phones.
5. Credits must stay visible (`MapCredit`). The OSM data licence requires it.

## 7. Platforms

**Android:** no new permissions or manifest entries. **iOS:** no new keys; all
providers are HTTPS, and location strings already exist. **Not tested on iOS.**

Tested on the API 36 emulator with simulated movement, signed in, against the
Firebase emulators and the real rules (2026-11-04). The same flow on the live
project, a real drive, GPS drift on a real road, and map performance on a mid-range
phone are all still to do.
