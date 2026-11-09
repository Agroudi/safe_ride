// What the web viewer decides, with no browser in it, so it can be tested:
// reading a link and a Firestore REST document, and how far to trust what is
// shown. The same rules as the app's `SharedView` (lib/.../shared_view.dart).

const TOKEN = /^[A-Za-z0-9_-]{43}$/;

/// A position older than this is no longer called live. The phone sends one
/// at least every minute while it has one.
export const STALE_AFTER_MS = 90 * 1000;

/// The token in a link's `#` part: browsers never send it to a server or in a
/// Referer. Null when it is not a well-formed token.
export function tokenFrom(hash) {
  const token = (hash ?? '').replace(/^#/, '');
  return TOKEN.test(token) ? token : null;
}

function value(field) {
  if (field == null) return undefined;
  if ('stringValue' in field) return field.stringValue;
  if ('integerValue' in field) return Number(field.integerValue);
  if ('doubleValue' in field) return field.doubleValue;
  if ('booleanValue' in field) return field.booleanValue;
  if ('timestampValue' in field) return new Date(field.timestampValue);
  if ('nullValue' in field) return null;
  if ('mapValue' in field) {
    const out = {};
    for (const [k, v] of Object.entries(field.mapValue.fields ?? {})) out[k] = value(v);
    return out;
  }
  if ('arrayValue' in field) return (field.arrayValue.values ?? []).map(value);
  return undefined;
}

/// A Firestore REST document as plain values.
export function fromFirestore(doc) {
  return value({ mapValue: { fields: doc?.fields ?? {} } });
}

function validPoint(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng)
    && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0);
}

function place(p) {
  if (!p || typeof p.name !== 'string' || !p.name) return null;
  return { name: p.name, point: validPoint(p.lat, p.lng) ? [p.lng, p.lat] : null };
}

/// The share, or null when the document cannot be read: nothing is shown from
/// a guess.
export function readShare(doc) {
  const d = fromFirestore(doc);
  if (!(d.expiresAt instanceof Date) || typeof d.kind !== 'string') return null;
  const location = d.location;
  return {
    kind: d.kind,
    expiresAt: d.expiresAt,
    tracking: d.tracking,
    point: location && validPoint(location.lat, location.lng)
      ? [location.lng, location.lat]
      : null,
    locationAt: d.locationAt instanceof Date ? d.locationAt : null,
    origin: place(d.origin),
    destination: place(d.destination),
    finished: d.journeyStatus === 'finished',
    distanceMeters: typeof d.distanceMeters === 'number' ? d.distanceMeters : null,
    routeChunks: Number.isInteger(d.routeChunks) ? d.routeChunks : 0,
    routeVersion: Number.isInteger(d.routeVersion) ? d.routeVersion : 0,
  };
}

/// `waiting`, `live`, `paused`, `stale`, `offline` or `finished`. [heardAt] is
/// when this device last got the document, so a recipient whose clock is
/// behind still sees an old position called old.
export function liveness(share, { now, heardAt, offline }) {
  if (share.finished) return 'finished';
  if (!share.point || !share.locationAt) return offline ? 'offline' : 'waiting';
  if (offline) return 'offline';
  if (share.tracking === 'paused') return 'paused';
  const old = now - share.locationAt > STALE_AFTER_MS || now - heardAt > STALE_AFTER_MS;
  return old ? 'stale' : 'live';
}

/// Chunks of points as unbroken lines: no line crosses a gap in the recording.
export function routeLines(chunks) {
  const lines = [];
  let current;
  for (const chunk of chunks) {
    for (const p of chunk ?? []) {
      if (!validPoint(p.lat, p.lng)) continue;
      if (p.seg !== current) {
        lines.push([]);
        current = p.seg;
      }
      lines[lines.length - 1].push([p.lng, p.lat]);
    }
  }
  return lines;
}

/// What can have changed since the last read: the last chunk held, and newer.
export function chunksToFetch(held, total) {
  const from = held === 0 ? 0 : held - 1;
  const out = [];
  for (let c = from; c < total; c += 1) out.push(c);
  return out;
}

export function chunkId(n) {
  return String(n).padStart(5, '0');
}
