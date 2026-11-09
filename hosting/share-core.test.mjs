// Run with: node --test hosting/share-core.test.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  STALE_AFTER_MS,
  chunkId,
  chunksToFetch,
  fromFirestore,
  liveness,
  readShare,
  routeLines,
  tokenFrom,
} from './share-core.mjs';

const token = 'Abc_-0123456789Abc_-0123456789Abc_-01234567';
const now = new Date('2026-11-04T12:00:00Z').getTime();

const doc = (extra = {}) => ({
  fields: {
    kind: { stringValue: 'journey' },
    expiresAt: { timestampValue: '2026-11-04T13:00:00Z' },
    tracking: { stringValue: 'live' },
    location: {
      mapValue: {
        fields: {
          lat: { doubleValue: 24.7 },
          lng: { doubleValue: 46.68 },
          accuracy: { integerValue: '8' },
        },
      },
    },
    locationAt: { timestampValue: '2026-11-04T11:59:50Z' },
    origin: { mapValue: { fields: { name: { stringValue: 'Olaya' } } } },
    journeyStatus: { stringValue: 'active' },
    routeChunks: { integerValue: '2' },
    routeVersion: { integerValue: '7' },
    ...extra,
  },
});

test('a token comes only from a well-formed # part', () => {
  assert.equal(tokenFrom(`#${token}`), token);
  assert.equal(tokenFrom(''), null);
  assert.equal(tokenFrom('#short'), null);
  assert.equal(tokenFrom(`#${token}x`), null);
  assert.equal(tokenFrom(`#${token.slice(0, 42)}!`), null);
  assert.equal(tokenFrom(undefined), null);
});

test('a Firestore REST document becomes plain values', () => {
  const d = fromFirestore(doc());
  assert.equal(d.kind, 'journey');
  assert.equal(d.routeChunks, 2);
  assert.equal(d.location.accuracy, 8);
  assert.ok(d.expiresAt instanceof Date);
});

test('a share is read, and a broken one is refused', () => {
  const share = readShare(doc());
  assert.deepEqual(share.point, [46.68, 24.7]);
  assert.equal(share.origin.name, 'Olaya');
  assert.equal(share.origin.point, null);
  assert.equal(share.routeVersion, 7);
  assert.equal(readShare({ fields: {} }), null);
  assert.equal(readShare(undefined), null);
});

test('bad coordinates are not a position', () => {
  const bad = { mapValue: { fields: { lat: { doubleValue: 91 }, lng: { doubleValue: 46 } } } };
  assert.equal(readShare(doc({ location: bad })).point, null);
});

test('a fresh position is live', () => {
  assert.equal(liveness(readShare(doc()), { now, heardAt: now, offline: false }), 'live');
});

test('an old position is never called live', () => {
  const share = readShare(doc());
  const later = now + STALE_AFTER_MS + 1000;
  assert.equal(liveness(share, { now: later, heardAt: later, offline: false }), 'stale');
});

test('nothing heard for a while is stale, whatever the clock says', () => {
  const share = readShare(doc());
  assert.equal(
    liveness(share, { now, heardAt: now - STALE_AFTER_MS - 1000, offline: false }),
    'stale',
  );
});

test('offline, paused, waiting and finished are said apart', () => {
  const share = readShare(doc());
  const at = { now, heardAt: now, offline: false };
  assert.equal(liveness(share, { ...at, offline: true }), 'offline');
  assert.equal(liveness({ ...share, tracking: 'paused' }, at), 'paused');
  assert.equal(liveness({ ...share, point: null }, at), 'waiting');
  assert.equal(liveness({ ...share, finished: true }, at), 'finished');
});

test('no line crosses a gap in the recording', () => {
  const lines = routeLines([
    [{ lat: 24.1, lng: 46.1, seg: 0 }, { lat: 24.2, lng: 46.2, seg: 0 }],
    [{ lat: 24.3, lng: 46.3, seg: 1 }, { lat: 91, lng: 46.4, seg: 1 }],
  ]);
  assert.equal(lines.length, 2);
  assert.equal(lines[0].length, 2);
  assert.deepEqual(lines[1], [[46.3, 24.3]]);
});

test('only chunks that can have changed are fetched', () => {
  assert.deepEqual(chunksToFetch(0, 2), [0, 1]);
  assert.deepEqual(chunksToFetch(3, 3), [2]);
  assert.deepEqual(chunksToFetch(3, 5), [2, 3, 4]);
  assert.equal(chunkId(7), '00007');
});
