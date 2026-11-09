// The recipient's page: read-only, no account, no cookies, no analytics. It
// reads one Firestore document by its token, over REST, and draws it. The token
// stays in the `#` part of the address: it is never sent to this site, and the
// no-referrer policy keeps it from any other.
import {
  chunkId,
  chunksToFetch,
  liveness,
  readShare,
  routeLines,
  tokenFrom,
  fromFirestore,
} from './share-core.mjs';

const POLL_MS = 15000;

const WORDS = {
  en: {
    location: 'Shared location',
    journey: 'Shared journey',
    route: (a, b) => `${a} to ${b}`,
    status: {
      waiting: 'Waiting for a location',
      live: 'Live',
      paused: 'Location unavailable',
      stale: 'Not up to date',
      offline: "You're offline: not up to date",
      finished: 'Journey finished',
    },
    updated: (t) => `Last updated at ${t}`,
    travelled: (d) => `Travelled: ${d} km`,
    ends: (t) => `Link ends at ${t}`,
    endedTitle: 'This share has ended',
    endedBody: "It was stopped or it expired, or the link isn't valid.",
    failedTitle: "Can't load this share",
    failedBody: 'Check your connection and open the link again.',
  },
  ar: {
    location: 'موقع مُشارَك',
    journey: 'رحلة مُشارَكة',
    route: (a, b) => `من ${a} إلى ${b}`,
    status: {
      waiting: 'في انتظار الموقع',
      live: 'مباشر',
      paused: 'الموقع غير متاح',
      stale: 'غير محدَّث',
      offline: 'أنت غير متصل: البيانات غير محدَّثة',
      finished: 'انتهت الرحلة',
    },
    updated: (t) => `آخر تحديث عند ${t}`,
    travelled: (d) => `المسافة المقطوعة: ${d} كم`,
    ends: (t) => `ينتهي الرابط عند ${t}`,
    endedTitle: 'انتهت هذه المشاركة',
    endedBody: 'أُوقفت أو انتهت مدتها، أو أن الرابط غير صالح.',
    failedTitle: 'تعذّر تحميل هذه المشاركة',
    failedBody: 'تحقق من اتصالك وافتح الرابط مرة أخرى.',
  },
};

const TONES = {
  live: 'live',
  waiting: 'info',
  finished: 'info',
  paused: 'warn',
  stale: 'warn',
  offline: 'warn',
};

const lang = (navigator.language ?? 'en').toLowerCase().startsWith('ar') ? 'ar' : 'en';
const words = WORDS[lang];
document.documentElement.lang = lang;
document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';

const config = window.SAFERIDE_SHARE;
const token = tokenFrom(location.hash);
const clock = new Intl.DateTimeFormat(lang === 'ar' ? 'ar-EG' : 'en', { timeStyle: 'short' });
const dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
const el = (id) => document.getElementById(id);

let map;
let dot;
const ends = [];
let share = null;
let heardAt = 0;
let offline = false;
let timer;
let loadedVersion = -1;
const chunks = [];

function showMessage(title, body) {
  clearTimeout(timer);
  el('panel').hidden = true;
  el('map').hidden = true;
  el('message-title').textContent = title;
  el('message-body').textContent = body;
  el('message').hidden = false;
}

function ended() {
  share = null;
  chunks.length = 0;
  showMessage(words.endedTitle, words.endedBody);
}

function setUpMap(center) {
  map = new window.maplibregl.Map({
    container: 'map',
    style: dark ? config.mapStyles.dark : config.mapStyles.light,
    center,
    zoom: 14,
    attributionControl: false,
  });
  // At the top: the panel covers the bottom, and the credit must stay visible.
  map.addControl(new window.maplibregl.AttributionControl({ compact: false }), 'top-right');
  map.touchZoomRotate.disableRotation();
  map.dragRotate.disable();
  // A route read before the map existed still has to be drawn.
  map.once('load', drawRoute);
}

function marker(kind, point) {
  const node = document.createElement('div');
  node.className = 'end';
  node.dataset.kind = kind;
  return new window.maplibregl.Marker({ element: node }).setLngLat(point).addTo(map);
}

function drawRoute() {
  if (!map?.loaded() && !map?.getSource('route')) return;
  const data = {
    type: 'FeatureCollection',
    features: routeLines(chunks).map((coordinates) => ({
      type: 'Feature',
      properties: {},
      geometry: { type: 'LineString', coordinates },
    })),
  };
  const source = map.getSource('route');
  if (source) {
    source.setData(data);
    return;
  }
  map.addSource('route', { type: 'geojson', data });
  map.addLayer({
    id: 'route',
    type: 'line',
    source: 'route',
    paint: { 'line-color': '#0f766e', 'line-width': 5 },
  });
}

function render() {
  if (!share) return;
  const state = liveness(share, { now: Date.now(), heardAt, offline });
  const center = share.point ?? share.origin?.point ?? share.destination?.point;
  if (!map && center) {
    setUpMap(center);
    for (const [kind, end] of [['origin', share.origin], ['destination', share.destination]]) {
      if (end?.point) ends.push(marker(kind, end.point));
    }
  }
  el('title').textContent = share.origin && share.destination
    ? words.route(share.origin.name, share.destination.name)
    : words[share.kind === 'journey' ? 'journey' : 'location'];
  el('status').textContent = words.status[state];
  el('status').dataset.tone = TONES[state];
  const lines = [];
  if (share.locationAt) lines.push(words.updated(clock.format(share.locationAt)));
  if (share.distanceMeters != null) {
    lines.push(words.travelled((share.distanceMeters / 1000).toFixed(2)));
  }
  lines.push(words.ends(clock.format(share.expiresAt)));
  el('details').textContent = lines.join('\n');

  if (map && share.point) {
    if (!dot) {
      const node = document.createElement('div');
      node.className = 'dot';
      dot = new window.maplibregl.Marker({ element: node }).setLngLat(share.point).addTo(map);
    }
    dot.setLngLat(share.point);
    // An old position is drawn muted: never as if it were live.
    dot.getElement().dataset.live = String(state === 'live');
    map.easeTo({ center: share.point, duration: 600 });
  } else if (dot) {
    dot.remove();
    dot = null;
  }
}

async function read(path) {
  // No credentials, no referrer: nothing but the address.
  return fetch(`${config.firestore}/${path}`, {
    credentials: 'omit',
    referrerPolicy: 'no-referrer',
    cache: 'no-store',
  });
}

async function loadRoute(next) {
  if (next.routeVersion === loadedVersion) return;
  const wanted = chunksToFetch(chunks.length, next.routeChunks);
  for (const c of wanted) {
    const response = await read(`shares/${token}/route/${chunkId(c)}`);
    if (!response.ok) return;
    chunks[c] = fromFirestore(await response.json()).points ?? [];
  }
  loadedVersion = next.routeVersion;
  if (chunks.length) drawRoute();
}

async function poll() {
  try {
    const response = await read(`shares/${token}`);
    // 403 is stopped, expired or never a share: the three look alike.
    if (response.status === 403 || response.status === 404) {
      ended();
      return;
    }
    if (!response.ok) throw new Error('unavailable');
    const next = readShare(await response.json());
    if (!next) {
      ended();
      return;
    }
    share = next;
    heardAt = Date.now();
    offline = false;
    await loadRoute(next);
  } catch {
    offline = true;
    if (!share) {
      showMessage(words.failedTitle, words.failedBody);
      return;
    }
  }
  if (share && share.expiresAt <= Date.now()) {
    ended();
    return;
  }
  render();
  schedule();
}

function schedule() {
  clearTimeout(timer);
  // A hidden page reads nothing: it costs reads and shows nobody anything.
  if (!document.hidden) timer = setTimeout(poll, POLL_MS);
}

document.addEventListener('visibilitychange', () => {
  if (!document.hidden && token && !el('panel').hidden) poll();
});

if (token) {
  poll();
} else {
  ended();
}
