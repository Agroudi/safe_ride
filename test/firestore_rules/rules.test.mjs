// Tests for firestore.rules — run with `npm test` in this folder (needs the
// Firebase CLI and JDK 21 for the emulator). Every rule the app relies on is
// checked from both sides: what the owner may do, and what nobody may.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-saferide',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const sara = () => env.authenticatedContext('sara').firestore();
const omar = () => env.authenticatedContext('omar').firestore();
const nobody = () => env.unauthenticatedContext().firestore();

const profile = (extra = {}) => ({
  fullName: 'Sara Ahmed',
  phone: null,
  locale: 'ar',
  updatedAt: serverTimestamp(),
  ...extra,
});

const journey = (extra = {}) => ({
  origin: 'Olaya Street',
  destination: 'Airport',
  departsAt: Timestamp.fromDate(new Date(Date.now() + 3600e3)),
  status: 'planned',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

const contact = (extra = {}) => ({
  fullName: 'Mona Saleh',
  phone: '+966 55 111 2222',
  phoneDigits: '966551112222',
  relationship: 'Sister',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

/// Writes as if by the app, bypassing the rules — for the "before" state.
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

describe('users/{uid}', () => {
  test('the owner creates, reads and updates their profile', async () => {
    await assertSucceeds(setDoc(doc(sara(), 'users/sara'), profile()));
    await assertSucceeds(getDoc(doc(sara(), 'users/sara')));
    await assertSucceeds(
      setDoc(doc(sara(), 'users/sara'), { fullName: 'Sara A', updatedAt: serverTimestamp() }, { merge: true }),
    );
  });

  test('nobody else reads or writes it', async () => {
    await seed('users/sara', profile({ updatedAt: Timestamp.now() }));
    await assertFails(getDoc(doc(omar(), 'users/sara')));
    await assertFails(getDoc(doc(nobody(), 'users/sara')));
    await assertFails(setDoc(doc(omar(), 'users/sara'), profile()));
  });

  test('unknown fields, a password, bad values and a forged time are refused', async () => {
    const ref = doc(sara(), 'users/sara');
    await assertFails(setDoc(ref, profile({ password: 'Secret123' })));
    await assertFails(setDoc(ref, profile({ email: 'sara@example.com' })));
    await assertFails(setDoc(ref, profile({ fullName: 'S' })));
    await assertFails(setDoc(ref, profile({ locale: 'fr' })));
    await assertFails(setDoc(ref, profile({ updatedAt: Timestamp.fromDate(new Date(2020, 0, 1)) })));
  });
});

describe('users/{uid}: the country the user is in', () => {
  test('the owner keeps a country code in their profile', async () => {
    const ref = doc(sara(), 'users/sara');
    await assertSucceeds(setDoc(ref, profile({ country: 'SA' })));
    await assertSucceeds(
      setDoc(ref, { country: 'EG', updatedAt: serverTimestamp() }, { merge: true }),
    );
  });

  test('anything but two capital letters is refused', async () => {
    const ref = doc(sara(), 'users/sara');
    await assertSucceeds(setDoc(ref, profile()));
    for (const bad of ['sa', 'SAU', 'S', '', 12, 'S1']) {
      await assertFails(
        setDoc(ref, { country: bad, updatedAt: serverTimestamp() }, { merge: true }),
      );
    }
  });

  test('nobody else sets it', async () => {
    await seed('users/sara', profile({ updatedAt: Timestamp.now() }));
    await assertFails(
      setDoc(doc(omar(), 'users/sara'), { country: 'QA', updatedAt: serverTimestamp() }, { merge: true }),
    );
  });
});

describe('users/{uid}/journeys', () => {
  test('the owner plans a journey; others cannot see it', async () => {
    await assertSucceeds(setDoc(doc(sara(), 'users/sara/journeys/j1'), journey()));
    await assertSucceeds(getDoc(doc(sara(), 'users/sara/journeys/j1')));
    await assertFails(getDoc(doc(omar(), 'users/sara/journeys/j1')));
    await assertFails(setDoc(doc(omar(), 'users/sara/journeys/j2'), journey()));
    await assertFails(getDoc(doc(nobody(), 'users/sara/journeys/j1')));
  });

  test('a new journey must be planned, complete and stamped by the server', async () => {
    const ref = doc(sara(), 'users/sara/journeys/j1');
    await assertFails(setDoc(ref, journey({ status: 'completed' })));
    await assertFails(setDoc(ref, journey({ origin: 'A' })));
    await assertFails(setDoc(ref, journey({ tracking: true })));
    await assertFails(setDoc(ref, journey({ createdAt: Timestamp.fromDate(new Date(2020, 0, 1)) })));
    const { departsAt, ...noDeparture } = journey();
    await assertFails(setDoc(ref, noDeparture));
  });

  test('a planned journey is edited and closed; a closed one never changes', async () => {
    await seed('users/sara/journeys/j1', journey({ createdAt: Timestamp.now(), updatedAt: Timestamp.now() }));
    const ref = doc(sara(), 'users/sara/journeys/j1');
    await assertSucceeds(updateDoc(ref, { destination: 'Riyadh Park', updatedAt: serverTimestamp() }));
    // Closing may not change anything else at the same time.
    await assertFails(updateDoc(ref, { status: 'cancelled', destination: 'X Y', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { status: 'cancelled', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: 'planned', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { destination: 'Mall', updatedAt: serverTimestamp() }));
  });

  test('createdAt never changes', async () => {
    await seed('users/sara/journeys/j1', journey({ createdAt: Timestamp.now(), updatedAt: Timestamp.now() }));
    await assertFails(
      updateDoc(doc(sara(), 'users/sara/journeys/j1'), {
        createdAt: Timestamp.fromDate(new Date(2020, 0, 1)),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

const CHECKLIST_V1 = [
  'vehicle', 'energy', 'tiresBrakes', 'documents', 'fitness', 'sober',
  'phoneBattery', 'contacts', 'assistance',
];

const checklist = (extra = {}) => ({
  journeyId: 'j1',
  uid: 'sara',
  version: 1,
  items: CHECKLIST_V1,
  complete: true,
  completedAt: serverTimestamp(),
  ...extra,
});

/// The app's start: the checklist record and planned → active, one batch.
function start(db, { record = checklist(), journey = 'j1', path = `users/sara/journeys/j1` } = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `${path}/checklists/preJourney`), record);
  batch.update(doc(db, path), {
    status: 'active',
    startedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

describe('starting a journey: the pre-journey checklist', () => {
  beforeEach(() =>
    seed('users/sara/journeys/j1', journey({ createdAt: Timestamp.now(), updatedAt: Timestamp.now() })));

  test('starts only together with a complete checklist record', async () => {
    await assertSucceeds(start(sara()));
    const after = await getDoc(doc(sara(), 'users/sara/journeys/j1'));
    if (after.data().status !== 'active') throw new Error('not active');
    await assertSucceeds(getDoc(doc(sara(), 'users/sara/journeys/j1/checklists/preJourney')));
  });

  test('a journey cannot become active without its checklist', async () => {
    await assertFails(
      updateDoc(doc(sara(), 'users/sara/journeys/j1'), {
        status: 'active',
        startedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('a checklist record alone, without the start, is refused', async () => {
    await assertFails(setDoc(doc(sara(), 'users/sara/journeys/j1/checklists/preJourney'), checklist()));
  });

  test('a missing item, a stray item or an unknown version is refused', async () => {
    await assertFails(start(sara(), { record: checklist({ items: CHECKLIST_V1.slice(1) }) }));
    await assertFails(start(sara(), { record: checklist({ items: [...CHECKLIST_V1.slice(1), 'other'] }) }));
    await assertFails(start(sara(), { record: checklist({ version: 2 }) }));
    await assertFails(start(sara(), { record: checklist({ complete: false }) }));
    await assertFails(start(sara(), { record: checklist({ journeyId: 'j2' }) }));
    await assertFails(start(sara(), { record: checklist({ completedAt: Timestamp.fromDate(new Date(2020, 0, 1)) }) }));
  });

  test('a journey starts once; its record never changes', async () => {
    await assertSucceeds(start(sara()));
    await assertFails(start(sara()));
    await assertFails(
      updateDoc(doc(sara(), 'users/sara/journeys/j1/checklists/preJourney'), { version: 1 }),
    );
  });

  test('nobody else starts it or reads its checklist', async () => {
    await assertFails(start(omar()));
    await assertSucceeds(start(sara()));
    await assertFails(getDoc(doc(omar(), 'users/sara/journeys/j1/checklists/preJourney')));
    await assertFails(getDoc(doc(nobody(), 'users/sara/journeys/j1/checklists/preJourney')));
  });

  test('completed only after it started; an active journey is not edited', async () => {
    const ref = doc(sara(), 'users/sara/journeys/j1');
    await assertFails(updateDoc(ref, { status: 'completed', updatedAt: serverTimestamp() }));
    await assertSucceeds(start(sara()));
    await assertFails(updateDoc(ref, { destination: 'Mall', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: 'planned', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { status: 'completed', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: 'active', updatedAt: serverTimestamp() }));
  });

  test('an active journey may be cancelled', async () => {
    await assertSucceeds(start(sara()));
    await assertSucceeds(
      updateDoc(doc(sara(), 'users/sara/journeys/j1'), { status: 'cancelled', updatedAt: serverTimestamp() }),
    );
  });

  test('a new journey is never created already started', async () => {
    await assertFails(setDoc(doc(sara(), 'users/sara/journeys/j9'), journey({ status: 'active' })));
    await assertFails(setDoc(doc(sara(), 'users/sara/journeys/j9'), journey({ startedAt: serverTimestamp() })));
  });
});

const point = (extra = {}) => ({
  lat: 24.7136,
  lng: 46.6753,
  at: Timestamp.now(),
  acc: 8,
  spd: 12.5,
  seg: 0,
  ...extra,
});

const chunk = (extra = {}) => ({
  chunk: 0,
  points: [point(), point({ lat: 24.7140, spd: null })],
  updatedAt: serverTimestamp(),
  ...extra,
});

const summary = (extra = {}) => ({
  distanceMeters: 44.5,
  pointCount: 2,
  recording: true,
  firstAt: Timestamp.now(),
  lastAt: Timestamp.now(),
  updatedAt: serverTimestamp(),
  ...extra,
});

describe('a journey\'s recorded route', () => {
  const ROUTE = 'users/sara/journeys/j1/route/00000';
  const SUMMARY = 'users/sara/journeys/j1/tracking/summary';
  const seedJourney = (status) =>
    seed('users/sara/journeys/j1', journey({
      status,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...(status === 'planned' ? {} : { startedAt: Timestamp.now() }),
    }));

  test('the owner writes chunks and the summary of a started journey', async () => {
    await seedJourney('active');
    await assertSucceeds(setDoc(doc(sara(), ROUTE), chunk()));
    await assertSucceeds(setDoc(doc(sara(), ROUTE), chunk({ points: [point(), point(), point()] })));
    await assertSucceeds(setDoc(doc(sara(), 'users/sara/journeys/j1/route/00001'), chunk({ chunk: 1 })));
    await assertSucceeds(setDoc(doc(sara(), SUMMARY), summary()));
    await assertSucceeds(getDoc(doc(sara(), ROUTE)));
    await assertSucceeds(getDoc(doc(sara(), SUMMARY)));
  });

  test('a route arriving after the journey ended is still accepted', async () => {
    await seedJourney('completed');
    await assertSucceeds(setDoc(doc(sara(), ROUTE), chunk()));
    await assertSucceeds(setDoc(doc(sara(), SUMMARY), summary({ recording: false })));
  });

  test('nothing is recorded for a journey that has not started', async () => {
    await seedJourney('planned');
    await assertFails(setDoc(doc(sara(), ROUTE), chunk()));
    await assertFails(setDoc(doc(sara(), SUMMARY), summary()));
    await assertFails(setDoc(doc(sara(), 'users/sara/journeys/nope/route/00000'), chunk()));
  });

  test('nobody else reads or writes it', async () => {
    await seedJourney('active');
    await assertSucceeds(setDoc(doc(sara(), ROUTE), chunk()));
    await assertFails(getDoc(doc(omar(), ROUTE)));
    await assertFails(getDoc(doc(nobody(), ROUTE)));
    await assertFails(setDoc(doc(omar(), ROUTE), chunk()));
    await assertFails(getDoc(doc(omar(), SUMMARY)));
    await assertFails(setDoc(doc(omar(), SUMMARY), summary()));
  });

  test('malformed chunks are refused', async () => {
    await seedJourney('active');
    const ref = doc(sara(), ROUTE);
    await assertFails(setDoc(ref, chunk({ chunk: 3 })));
    await assertFails(setDoc(doc(sara(), 'users/sara/journeys/j1/route/0'), chunk()));
    await assertFails(setDoc(ref, chunk({ points: [] })));
    await assertFails(setDoc(ref, chunk({ points: Array.from({ length: 101 }, () => point()) })));
    await assertFails(setDoc(ref, chunk({ points: [point({ lat: 91 })] })));
    await assertFails(setDoc(ref, chunk({ points: [point(), point({ lng: 'x' })] })));
    await assertFails(setDoc(ref, chunk({ points: [point({ owner: 'omar' })] })));
    await assertFails(setDoc(ref, chunk({ extra: true })));
    await assertFails(setDoc(ref, chunk({ updatedAt: Timestamp.fromDate(new Date(2020, 0, 1)) })));
  });

  test('a malformed summary is refused', async () => {
    await seedJourney('active');
    const ref = doc(sara(), SUMMARY);
    await assertFails(setDoc(ref, summary({ distanceMeters: -1 })));
    await assertFails(setDoc(ref, summary({ pointCount: 1.5 })));
    await assertFails(setDoc(ref, summary({ recording: 'yes' })));
    await assertFails(setDoc(ref, summary({ extra: 1 })));
    await assertFails(setDoc(doc(sara(), 'users/sara/journeys/j1/tracking/other'), summary()));
  });
});

describe('users/{uid}/contacts', () => {
  test('the owner adds, edits and deletes; others cannot touch them', async () => {
    const ref = doc(sara(), 'users/sara/contacts/c1');
    await assertSucceeds(setDoc(ref, contact()));
    await assertFails(getDoc(doc(omar(), 'users/sara/contacts/c1')));
    await assertFails(deleteDoc(doc(omar(), 'users/sara/contacts/c1')));
    await assertSucceeds(
      updateDoc(ref, { fullName: 'Mona S', relationship: null, updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(ref));
  });

  test('bad numbers, extra fields and a long relationship are refused', async () => {
    const ref = doc(sara(), 'users/sara/contacts/c1');
    await assertFails(setDoc(ref, contact({ phoneDigits: '12ab' })));
    await assertFails(setDoc(ref, contact({ verified: true })));
    await assertFails(setDoc(ref, contact({ relationship: 'x'.repeat(41) })));
    const { phone, ...noPhone } = contact();
    await assertFails(setDoc(ref, noPhone));
  });
});

describe('users/{uid}/devices', () => {
  test('the owner keeps this install\'s FCM id; others cannot', async () => {
    const data = { fid: 'fid-0123456789', platform: 'android', updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(sara(), 'users/sara/devices/install1'), data));
    await assertFails(setDoc(doc(omar(), 'users/sara/devices/install1'), data));
    await assertFails(setDoc(doc(sara(), 'users/sara/devices/install2'), { ...data, platform: 'web' }));
    await assertSucceeds(deleteDoc(doc(sara(), 'users/sara/devices/install1')));
  });
});

describe('escalation requests', () => {
  const past = Timestamp.fromDate(new Date(Date.now() - 60e3));
  const check = (extra = {}) => ({
    uid: 'sara',
    journeyId: 'j1',
    incidentId: 'e1',
    status: 'escalationReady',
    startedAt: past,
    deadline: past,
    timedOutAt: past,
    escalationReadyAt: past,
    syncedAt: serverTimestamp(),
    ...extra,
  });
  const incident = (extra = {}) => ({
    journeyId: 'j1',
    safetyCheckId: 'e1-check',
    type: 'prolongedStop',
    confidence: 'medium',
    detectedAt: past,
    createdAt: serverTimestamp(),
    ...extra,
  });

  /** Writes the request as the app does: both documents, one write. */
  function send(db, uid, checkData, incidentData) {
    const batch = writeBatch(db);
    batch.set(doc(db, `users/${uid}/incidents/e1`), incidentData);
    batch.set(doc(db, `users/${uid}/safetyChecks/e1-check`), checkData);
    return batch.commit();
  }

  beforeEach(() => seed('users/sara/journeys/j1', { status: 'active' }));

  test('the owner reports an unanswered check, with its incident', async () => {
    await assertSucceeds(send(sara(), 'sara', check(), incident()));
    await assertSucceeds(getDoc(doc(sara(), 'users/sara/safetyChecks/e1-check')));
    await assertSucceeds(getDoc(doc(sara(), 'users/sara/incidents/e1')));
  });

  test('nobody else reports for them, or reads it', async () => {
    await assertFails(send(omar(), 'sara', check(), incident()));
    await assertFails(send(nobody(), 'sara', check(), incident()));
    await assertSucceeds(send(sara(), 'sara', check(), incident()));
    await assertFails(getDoc(doc(omar(), 'users/sara/safetyChecks/e1-check')));
    await assertFails(getDoc(doc(omar(), 'users/sara/incidents/e1')));
    await assertFails(getDoc(doc(nobody(), 'users/sara/safetyChecks/e1-check')));
  });

  test('a check naming another account is refused', async () => {
    await assertFails(send(sara(), 'sara', check({ uid: 'omar' }), incident()));
  });

  test('only an escalation-ready check, past its deadline', async () => {
    await assertFails(
      send(sara(), 'sara', check({ status: 'timedOut' }), incident()),
    );
    await assertFails(
      send(sara(), 'sara', check({ status: 'confirmedSafe' }), incident()),
    );
    const soon = Timestamp.fromDate(new Date(Date.now() + 60e3));
    await assertFails(
      send(sara(), 'sara', check({ deadline: soon, timedOutAt: soon }), incident()),
    );
  });

  test('the sync time is the server\'s', async () => {
    await assertFails(send(sara(), 'sara', check({ syncedAt: past }), incident()));
  });

  test('a journey of another account, or none, is refused', async () => {
    await seed('users/omar/journeys/j2', { status: 'active' });
    await assertFails(
      send(
        sara(),
        'sara',
        check({ journeyId: 'j2' }),
        incident({ journeyId: 'j2' }),
      ),
    );
  });

  test('an incident cannot be added to a check already sent', async () => {
    await assertSucceeds(send(sara(), 'sara', check(), incident()));
    await assertFails(
      setDoc(doc(sara(), 'users/sara/incidents/e2'), incident()),
    );
  });

  test('the check and the incident must name each other', async () => {
    await assertFails(
      send(sara(), 'sara', check(), incident({ safetyCheckId: 'other' })),
    );
    await assertFails(
      send(sara(), 'sara', check(), incident({ journeyId: 'j9' })),
    );
    await assertFails(
      setDoc(doc(sara(), 'users/sara/safetyChecks/e1-check'), check()),
    );
    await assertFails(setDoc(doc(sara(), 'users/sara/incidents/e1'), incident()));
  });

  test('no location, no extra fields, only movement events', async () => {
    await assertFails(
      send(sara(), 'sara', check(), incident({ latitude: 24.7 })),
    );
    await assertFails(
      send(sara(), 'sara', check({ escalated: true }), incident()),
    );
    await assertFails(
      send(sara(), 'sara', check(), incident({ type: 'trackingInterrupted' })),
    );
    await assertFails(
      send(sara(), 'sara', check(), incident({ confidence: 'low' })),
    );
  });

  test('once sent, it never changes and is never removed', async () => {
    await assertSucceeds(send(sara(), 'sara', check(), incident()));
    const ref = doc(sara(), 'users/sara/safetyChecks/e1-check');
    await assertFails(updateDoc(ref, { status: 'confirmedSafe' }));
    await assertFails(setDoc(ref, check()));
    await assertFails(deleteDoc(ref));
    await assertFails(deleteDoc(doc(sara(), 'users/sara/incidents/e1')));
    await assertFails(
      updateDoc(doc(sara(), 'users/sara/incidents/e1'), { type: 'suddenDeceleration' }),
    );
  });
});

describe('a journey\'s places', () => {
  const place = (extra = {}) => ({ name: 'Riyadh', lat: 24.7, lng: 46.7, ...extra });

  test('a journey may carry places and an estimate, or none', async () => {
    await assertSucceeds(setDoc(doc(sara(), 'users/sara/journeys/j1'), journey({
      originPlace: place({ address: 'Olaya', placeId: 'N123' }),
      destinationPlace: place(),
      plannedDistanceMeters: 1200.5,
      plannedDurationSeconds: 300,
    })));
    await assertSucceeds(setDoc(doc(sara(), 'users/sara/journeys/j2'), journey()));
  });

  test('coordinates out of range or not numbers are refused', async () => {
    const ref = doc(sara(), 'users/sara/journeys/j1');
    await assertFails(setDoc(ref, journey({ originPlace: place({ lat: 91 }) })));
    await assertFails(setDoc(ref, journey({ originPlace: place({ lng: -181 }) })));
    await assertFails(setDoc(ref, journey({ destinationPlace: place({ lat: '24' }) })));
    const { lat, ...noLat } = place();
    await assertFails(setDoc(ref, journey({ originPlace: noLat })));
  });

  test('nothing rides along in a place', async () => {
    const ref = doc(sara(), 'users/sara/journeys/j1');
    await assertFails(setDoc(ref, journey({ originPlace: place({ uid: 'omar' }) })));
    await assertFails(setDoc(ref, journey({ plannedDistanceMeters: -1 })));
    await assertFails(setDoc(ref, journey({ route: [] })));
  });

  test('a planned journey can change its places; nobody else can', async () => {
    const ref = doc(sara(), 'users/sara/journeys/j1');
    await assertSucceeds(setDoc(ref, journey({ originPlace: place() })));
    await assertSucceeds(updateDoc(ref, {
      originPlace: place({ name: 'Jeddah' }),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(omar(), 'users/sara/journeys/j1'), {
      originPlace: place(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(getDoc(doc(omar(), 'users/sara/journeys/j1')));
  });
});

describe('location and journey sharing', () => {
  const token = 'Abc_-0123456789Abc_-0123456789Abc_-01234567';
  const other = 'Zzz_-0123456789Zzz_-0123456789Zzz_-01234567';
  const later = (minutes) => Timestamp.fromDate(new Date(Date.now() + minutes * 60e3));
  const earlier = () => Timestamp.fromDate(new Date(Date.now() - 60e3));

  const share = (extra = {}) => ({
    kind: 'journey',
    createdAt: serverTimestamp(),
    expiresAt: later(30),
    updatedAt: serverTimestamp(),
    tracking: 'waiting',
    origin: { name: 'Olaya', lat: 24.7, lng: 46.68 },
    destination: { name: 'Airport' },
    journeyStatus: 'active',
    routeChunks: 0,
    routeVersion: 0,
    ...extra,
  });
  const record = (extra = {}) => ({
    kind: 'journey',
    journeyId: 'j1',
    createdAt: serverTimestamp(),
    expiresAt: later(30),
    ...extra,
  });
  const located = (extra = {}) => ({
    tracking: 'live',
    location: { lat: 24.71, lng: 46.69, accuracy: 8, fixAt: Timestamp.now() },
    locationAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...extra,
  });

  /// As the app creates one: both documents in one write.
  function create(db, t = token, publicDoc = share(), ownerDoc = record(), uid = 'sara') {
    const batch = writeBatch(db);
    batch.set(doc(db, `shares/${t}`), publicDoc);
    batch.set(doc(db, `users/${uid}/shares/${t}`), ownerDoc);
    return batch.commit();
  }

  /// An open share of Sara's, as the server would hold it.
  async function open(extra = {}) {
    await seed(`users/sara/shares/${token}`, { kind: 'journey', journeyId: 'j1', createdAt: Timestamp.now(), expiresAt: later(30) });
    await seed(`shares/${token}`, {
      ...share(),
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...extra,
    });
  }

  test('the owner creates a share; a recipient with the link reads it', async () => {
    await assertSucceeds(create(sara()));
    await assertSucceeds(getDoc(doc(nobody(), `shares/${token}`)));
    await assertSucceeds(getDoc(doc(omar(), `shares/${token}`)));
  });

  test('a current-location share carries nothing of a journey', async () => {
    const plain = { kind: 'location', createdAt: serverTimestamp(), expiresAt: later(15), updatedAt: serverTimestamp(), tracking: 'waiting', routeChunks: 0, routeVersion: 0 };
    const mine = { kind: 'location', createdAt: serverTimestamp(), expiresAt: later(15) };
    await assertSucceeds(create(sara(), token, plain, mine));
    await assertFails(create(sara(), other, { ...plain, destination: { name: 'Home' } }, mine));
    await assertFails(create(sara(), other, plain, { ...mine, journeyId: 'j1' }));
  });

  test('nothing identifies the owner in the public document', async () => {
    await assertFails(create(sara(), token, share({ ownerUid: 'sara' })));
    await assertFails(create(sara(), token, share({ email: 'sara@example.com' })));
    await assertFails(create(sara(), token, share({ journeyId: 'j1' })));
  });

  test('a share needs its owner record, in the same write', async () => {
    await assertFails(setDoc(doc(sara(), `shares/${token}`), share()));
    await assertFails(setDoc(doc(sara(), `users/sara/shares/${token}`), record()));
    await assertFails(setDoc(doc(nobody(), `shares/${token}`), share()));
    await assertFails(create(omar(), token, share(), record(), 'sara'));
  });

  test('a short or malformed token is refused', async () => {
    await assertFails(create(sara(), 'j1'));
    await assertFails(create(sara(), 'a'.repeat(42)));
    await assertFails(create(sara(), `${'a'.repeat(42)}!`));
  });

  test('a share lasts at most 12 hours, and starts in the future', async () => {
    await assertFails(create(sara(), token, share({ expiresAt: later(12 * 60 + 5) })));
    await assertFails(create(sara(), token, share({ expiresAt: earlier() })));
    await assertSucceeds(create(sara(), token, share({ expiresAt: later(12 * 60 - 5) })));
  });

  test('it starts with no position and a forged start is refused', async () => {
    await assertFails(create(sara(), token, share({ tracking: 'live' })));
    await assertFails(create(sara(), token, share(located())));
    await assertFails(create(sara(), token, share({ createdAt: earlier() })));
  });

  test('a token already in use cannot be claimed by anyone', async () => {
    await open();
    await assertFails(setDoc(doc(omar(), `users/omar/shares/${token}`), record()));
    await assertFails(create(omar(), token, share(), record(), 'omar'));
    await assertFails(updateDoc(doc(omar(), `shares/${token}`), located()));
    await assertFails(deleteDoc(doc(omar(), `shares/${token}`)));
  });

  test('a recipient cannot list shares, signed in or not', async () => {
    await open();
    await assertFails(getDocs(collection(nobody(), 'shares')));
    await assertFails(getDocs(collection(omar(), 'shares')));
    await assertFails(getDocs(collection(sara(), 'shares')));
  });

  test('an expired link is refused, though the document is still there', async () => {
    await open({ expiresAt: earlier() });
    await assertFails(getDoc(doc(nobody(), `shares/${token}`)));
    await assertFails(getDoc(doc(omar(), `shares/${token}`)));
    await assertFails(updateDoc(doc(sara(), `shares/${token}`), located()));
  });

  test('stopping it ends the link at once', async () => {
    await open();
    const db = sara();
    const batch = writeBatch(db);
    batch.delete(doc(db, `shares/${token}`));
    batch.delete(doc(db, `users/sara/shares/${token}`));
    await assertSucceeds(batch.commit());
    await assertFails(getDoc(doc(nobody(), `shares/${token}`)));
  });

  test('an expired share can still be cleared by its owner', async () => {
    await open({ expiresAt: earlier() });
    await assertSucceeds(deleteDoc(doc(sara(), `shares/${token}`)));
  });

  test('the owner record cannot go first, leaving the link undeletable', async () => {
    await open();
    await assertFails(deleteDoc(doc(sara(), `users/sara/shares/${token}`)));
  });

  test('the owner publishes a position, stamped by the server', async () => {
    await open();
    await assertSucceeds(updateDoc(doc(sara(), `shares/${token}`), located()));
    await assertFails(updateDoc(doc(sara(), `shares/${token}`), located({ locationAt: Timestamp.now() })));
  });

  test('bad coordinates and accuracy are refused', async () => {
    await open();
    const at = Timestamp.now();
    for (const location of [
      { lat: 91, lng: 46, accuracy: 8, fixAt: at },
      { lat: 24, lng: 181, accuracy: 8, fixAt: at },
      { lat: '24', lng: 46, accuracy: 8, fixAt: at },
      { lat: 24, lng: 46, accuracy: 51, fixAt: at },
      { lat: 24, lng: 46, accuracy: 0, fixAt: at },
      { lat: 24, lng: 46, accuracy: 8, fixAt: at, speed: 9 },
      { lat: 24, lng: 46, accuracy: 8 },
    ]) {
      await assertFails(updateDoc(doc(sara(), `shares/${token}`), located({ location })));
    }
  });

  test('nobody but the owner changes anything', async () => {
    await open();
    for (const db of [nobody(), omar()]) {
      await assertFails(updateDoc(doc(db, `shares/${token}`), located()));
      await assertFails(updateDoc(doc(db, `shares/${token}`), { expiresAt: later(60), updatedAt: serverTimestamp() }));
      await assertFails(deleteDoc(doc(db, `shares/${token}`)));
    }
    await assertFails(getDoc(doc(omar(), `users/sara/shares/${token}`)));
    await assertFails(getDoc(doc(nobody(), `users/sara/shares/${token}`)));
  });

  test('the time can be shortened, never extended', async () => {
    await open();
    await assertFails(updateDoc(doc(sara(), `shares/${token}`), { expiresAt: later(45), updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(sara(), `shares/${token}`), { expiresAt: later(10), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(sara(), `users/sara/shares/${token}`), { expiresAt: later(45) }));
    await assertSucceeds(updateDoc(doc(sara(), `users/sara/shares/${token}`), { expiresAt: later(10) }));
  });

  test('what it shares cannot be swapped after it starts', async () => {
    await open();
    for (const change of [{ kind: 'location' }, { origin: { name: 'Elsewhere' } }, { destination: { name: 'Elsewhere' } }, { createdAt: Timestamp.now() }]) {
      await assertFails(updateDoc(doc(sara(), `shares/${token}`), { ...change, updatedAt: serverTimestamp() }));
    }
  });

  test('a finished journey drops its position and never comes back', async () => {
    await open(located({ updatedAt: Timestamp.now(), locationAt: Timestamp.now() }));
    await assertSucceeds(updateDoc(doc(sara(), `shares/${token}`), {
      journeyStatus: 'finished',
      tracking: 'ended',
      location: deleteField(),
      locationAt: deleteField(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(sara(), `shares/${token}`), located({ journeyStatus: 'active' })));
    await assertSucceeds(getDoc(doc(nobody(), `shares/${token}`)));
  });

  describe('the route', () => {
    const chunk = (extra = {}) => ({
      chunk: 0,
      points: [{ lat: 24.7, lng: 46.68, seg: 0 }, { lat: 24.71, lng: 46.68, seg: 1 }],
      updatedAt: serverTimestamp(),
      ...extra,
    });

    test('the owner writes chunks; a recipient reads one, never a list', async () => {
      await open();
      await assertSucceeds(setDoc(doc(sara(), `shares/${token}/route/00000`), chunk()));
      await assertSucceeds(getDoc(doc(nobody(), `shares/${token}/route/00000`)));
      await assertFails(getDocs(collection(nobody(), `shares/${token}/route`)));
      await assertFails(getDocs(collection(omar(), `shares/${token}/route`)));
      await assertSucceeds(getDocs(collection(sara(), `shares/${token}/route`)));
    });

    test('expiring or stopping the share closes its route too', async () => {
      await open({ expiresAt: earlier() });
      await seed(`shares/${token}/route/00000`, { chunk: 0, points: [] });
      await assertFails(getDoc(doc(nobody(), `shares/${token}/route/00000`)));
      await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), `shares/${token}`)));
      await assertFails(getDoc(doc(nobody(), `shares/${token}/route/00000`)));
    });

    test('nobody else writes it, and bad chunks are refused', async () => {
      await open();
      await assertFails(setDoc(doc(omar(), `shares/${token}/route/00000`), chunk()));
      await assertFails(setDoc(doc(nobody(), `shares/${token}/route/00000`), chunk()));
      await assertFails(setDoc(doc(sara(), `shares/${token}/route/00000`), chunk({ points: [] })));
      await assertFails(setDoc(doc(sara(), `shares/${token}/route/00001`), chunk()));
      await assertFails(setDoc(doc(sara(), `shares/${token}/route/00000`), chunk({ points: [{ lat: 95, lng: 46, seg: 0 }] })));
      await assertFails(setDoc(doc(sara(), `shares/${token}/route/00000`), chunk({ points: [{ lat: 24, lng: 46, seg: 0, at: 1 }] })));
      await assertFails(setDoc(doc(sara(), `shares/${token}/route/00040`), chunk({ chunk: 40 })));
    });

    test('a shared location has no route', async () => {
      await open({ kind: 'location', origin: null });
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `shares/${token}`), { kind: 'location', createdAt: Timestamp.now(), expiresAt: later(30), updatedAt: Timestamp.now(), tracking: 'live', routeChunks: 0, routeVersion: 0 });
      });
      await assertFails(setDoc(doc(sara(), `shares/${token}/route/00000`), chunk()));
    });
  });

  test('the link opens nothing private', async () => {
    await open();
    const paths = [
      'users/sara',
      'users/sara/journeys/j1',
      'users/sara/journeys/j1/route/00000',
      'users/sara/contacts/c1',
      'users/sara/devices/d1',
      'users/sara/safetyChecks/s1',
      'users/sara/incidents/i1',
      'users/sara/escalations/e1',
      'users/sara/contactLinks/l1',
      'users/sara/receivedAlerts/a1',
      `users/sara/shares/${token}`,
      'contactInvites/i1',
    ];
    for (const path of paths) {
      await seed(path, { status: 'planned' });
      await assertFails(getDoc(doc(nobody(), path)));
      await assertFails(getDoc(doc(omar(), path)));
    }
    await assertFails(getDocs(collection(nobody(), 'users')));
    await assertFails(getDocs(collection(omar(), 'users/sara/shares')));
  });

  test('account deletion removes every share, as one write each', async () => {
    await open();
    await seed(`shares/${token}/route/00000`, { chunk: 0, points: [] });
    const db = sara();
    const mine = await assertSucceeds(getDocs(collection(db, 'users/sara/shares')));
    assert.equal(mine.size, 1);
    const chunks = await assertSucceeds(getDocs(collection(db, `shares/${token}/route`)));
    const batch = writeBatch(db);
    chunks.forEach((c) => batch.delete(c.ref));
    batch.delete(doc(db, `shares/${token}`));
    batch.delete(doc(db, `users/sara/shares/${token}`));
    await assertSucceeds(batch.commit());
    await assertFails(getDoc(doc(nobody(), `shares/${token}`)));
  });
});

describe('connections between accounts', () => {
  const token = 'Inv_-0123456789Inv_-0123456789Inv_-01234567';
  const later = (minutes) => Timestamp.fromDate(new Date(Date.now() + minutes * 60e3));
  const earlier = () => Timestamp.fromDate(new Date(Date.now() - 60e3));
  const mona = () => env.authenticatedContext('mona').firestore();
  const made = Timestamp.fromDate(new Date(Date.now() - 3600e3));

  const newInvite = (extra = {}) => ({
    inviterUid: 'sara',
    inviterName: 'Sara Ahmed',
    status: 'pending',
    createdAt: serverTimestamp(),
    expiresAt: later(60 * 72),
    ...extra,
  });

  /// Both profiles, and a pending invite of Sara's, as the server would hold it.
  async function invited(extra = {}) {
    await seed('users/sara', { fullName: 'Sara Ahmed', updatedAt: Timestamp.now() });
    await seed('users/omar', { fullName: 'Omar Ali', updatedAt: Timestamp.now() });
    await seed('users/mona', { fullName: 'Mona Saleh', updatedAt: Timestamp.now() });
    await seed(`connectionInvites/${token}`, { ...newInvite(), createdAt: made, ...extra });
  }

  const record = (owner, contact, name, extra = {}) => ({
    ownerUid: owner,
    contactUid: contact,
    contactName: name,
    status: 'accepted',
    inviteId: token,
    createdAt: made,
    acceptedAt: serverTimestamp(),
    permissions: { safetyAlerts: false },
    ...extra,
  });

  /// As the app accepts: the invite and both sides, in one write.
  function accept(db, who = 'omar', name = 'Omar Ali', tweak = {}) {
    const batch = writeBatch(db);
    batch.update(doc(db, `connectionInvites/${token}`), {
      status: 'accepted',
      acceptedBy: who,
      acceptedAt: serverTimestamp(),
      ...tweak.invite,
    });
    batch.set(doc(db, `users/${who}/connections/sara`), record(who, 'sara', 'Sara Ahmed', tweak.mine));
    batch.set(doc(db, `users/sara/connections/${who}`), record('sara', who, name, tweak.theirs));
    return batch.commit();
  }

  /// A connection that exists, by way of the real write.
  async function connected() {
    await invited();
    await assertSucceeds(accept(omar()));
  }

  const ended = (who) => ({ status: 'revoked', revokedAt: serverTimestamp(), revokedBy: who });

  describe('inviting', () => {
    beforeEach(() => seed('users/sara', { fullName: 'Sara Ahmed', updatedAt: Timestamp.now() }));

    test('the owner invites, under their own name', async () => {
      await assertSucceeds(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite()));
    });

    test('nobody invites as someone else, or under another name', async () => {
      await assertFails(setDoc(doc(omar(), `connectionInvites/${token}`), newInvite()));
      await assertFails(setDoc(doc(nobody(), `connectionInvites/${token}`), newInvite()));
      await assertFails(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite({ inviterName: 'Hospital' })));
    });

    test('a short token, a long life or a forged state is refused', async () => {
      await assertFails(setDoc(doc(sara(), 'connectionInvites/short'), newInvite()));
      await assertFails(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite({ expiresAt: later(60 * 74) })));
      await assertFails(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite({ expiresAt: earlier() })));
      await assertFails(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite({ status: 'accepted' })));
      await assertFails(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite({ createdAt: made })));
      await assertFails(setDoc(doc(sara(), `connectionInvites/${token}`), newInvite({ email: 'x@y.z' })));
    });
  });

  describe('reading an invite', () => {
    test('a signed-in holder reads an open one; signed out, nobody does', async () => {
      await invited();
      await assertSucceeds(getDoc(doc(omar(), `connectionInvites/${token}`)));
      await assertFails(getDoc(doc(nobody(), `connectionInvites/${token}`)));
    });

    test('an expired or used one closes to everyone but its two people', async () => {
      await invited({ expiresAt: earlier() });
      await assertFails(getDoc(doc(omar(), `connectionInvites/${token}`)));
      await assertSucceeds(getDoc(doc(sara(), `connectionInvites/${token}`)));
      await seed(`connectionInvites/${token}`, { ...newInvite(), createdAt: made, status: 'accepted', acceptedBy: 'omar' });
      await assertSucceeds(getDoc(doc(omar(), `connectionInvites/${token}`)));
      await assertFails(getDoc(doc(mona(), `connectionInvites/${token}`)));
    });

    test('nobody lists invites but their own', async () => {
      await invited();
      const all = collection(omar(), 'connectionInvites');
      await assertFails(getDocs(all));
      await assertFails(getDocs(query(all, where('inviterUid', '==', 'sara'))));
      await assertFails(getDocs(collection(nobody(), 'connectionInvites')));
      await assertSucceeds(getDocs(query(collection(sara(), 'connectionInvites'), where('inviterUid', '==', 'sara'))));
    });
  });

  describe('accepting', () => {
    test('one write makes both sides', async () => {
      await invited();
      await assertSucceeds(accept(omar()));
      await assertSucceeds(getDoc(doc(omar(), 'users/omar/connections/sara')));
      await assertSucceeds(getDoc(doc(sara(), 'users/sara/connections/omar')));
    });

    test('an invite works once, even for a second person', async () => {
      await connected();
      await assertFails(accept(omar()));
      await assertFails(accept(mona(), 'mona', 'Mona Saleh'));
    });

    test('two people accepting at once: exactly one gets it', async () => {
      await invited();
      const attempt = (db, who, name) => runTransaction(db, async (tx) => {
        const ref = doc(db, `connectionInvites/${token}`);
        const invite = await tx.get(ref);
        if (invite.data().status !== 'pending') throw new Error('used');
        tx.update(ref, { status: 'accepted', acceptedBy: who, acceptedAt: serverTimestamp() });
        tx.set(doc(db, `users/${who}/connections/sara`), record(who, 'sara', 'Sara Ahmed'));
        tx.set(doc(db, `users/sara/connections/${who}`), record('sara', who, name));
      });
      const results = await Promise.allSettled([
        attempt(omar(), 'omar', 'Omar Ali'),
        attempt(mona(), 'mona', 'Mona Saleh'),
      ]);
      assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
      const connected = await getDocs(collection(sara(), 'users/sara/connections'));
      assert.equal(connected.size, 1);
    });

    test('an expired invite cannot be accepted', async () => {
      await invited({ expiresAt: earlier() });
      await assertFails(accept(omar()));
    });

    test('nobody accepts their own', async () => {
      await invited();
      await assertFails(accept(sara(), 'sara', 'Sara Ahmed'));
    });

    test('signed out, nothing is accepted', async () => {
      await invited();
      await assertFails(accept(nobody()));
    });

    test('accepting for someone else is refused', async () => {
      await invited();
      await assertFails(accept(mona(), 'omar', 'Omar Ali'));
    });

    test('a cancelled invite is gone', async () => {
      await invited();
      await assertSucceeds(deleteDoc(doc(sara(), `connectionInvites/${token}`)));
      await assertFails(accept(omar()));
    });

    test('an invite from a deleted account cannot be accepted', async () => {
      await invited();
      await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'users/sara')));
      await assertFails(accept(omar()));
    });

    test('it must be all three documents, in one write', async () => {
      await invited();
      const db = omar();
      await assertFails(updateDoc(doc(db, `connectionInvites/${token}`), { status: 'accepted', acceptedBy: 'omar', acceptedAt: serverTimestamp() }));
      await assertFails(setDoc(doc(db, 'users/omar/connections/sara'), record('omar', 'sara', 'Sara Ahmed')));
      await assertFails(setDoc(doc(db, 'users/sara/connections/omar'), record('sara', 'omar', 'Omar Ali')));
      const one = writeBatch(db);
      one.update(doc(db, `connectionInvites/${token}`), { status: 'accepted', acceptedBy: 'omar', acceptedAt: serverTimestamp() });
      one.set(doc(db, 'users/omar/connections/sara'), record('omar', 'sara', 'Sara Ahmed'));
      await assertFails(one.commit());
    });

    test('nobody connects two other accounts', async () => {
      await invited();
      const db = mona();
      const batch = writeBatch(db);
      batch.update(doc(db, `connectionInvites/${token}`), { status: 'accepted', acceptedBy: 'mona', acceptedAt: serverTimestamp() });
      batch.set(doc(db, 'users/omar/connections/sara'), record('omar', 'sara', 'Sara Ahmed'));
      batch.set(doc(db, 'users/sara/connections/omar'), record('sara', 'omar', 'Omar Ali'));
      await assertFails(batch.commit());
    });

    test('a forged name, permission or field is refused', async () => {
      await invited();
      await assertFails(accept(omar(), 'omar', 'Your Bank'));
      await assertFails(accept(omar(), 'omar', 'Omar Ali', { mine: { contactName: 'Someone Else' } }));
      await assertFails(accept(omar(), 'omar', 'Omar Ali', { theirs: { permissions: { safetyAlerts: true } } }));
      await assertFails(accept(omar(), 'omar', 'Omar Ali', { mine: { permissions: { location: true, safetyAlerts: false } } }));
      await assertFails(accept(omar(), 'omar', 'Omar Ali', { theirs: { location: { lat: 24, lng: 46 } } }));
      await assertFails(accept(omar(), 'omar', 'Omar Ali', { theirs: { nickname: 'Boss' } }));
      await assertFails(accept(omar(), 'omar', 'Omar Ali', { invite: { acceptedBy: 'mona' } }));
    });

    test('an old invite cannot be replayed to write a record', async () => {
      await connected();
      const db = omar();
      await assertFails(setDoc(doc(db, 'users/mona/connections/omar'), record('mona', 'omar', 'Omar Ali')));
      await assertFails(setDoc(doc(db, 'users/sara/connections/omar'), record('sara', 'omar', 'Omar Ali')));
    });
  });

  describe('a connection', () => {
    test('only its owner reads it, and nobody lists another account', async () => {
      await connected();
      await assertFails(getDoc(doc(omar(), 'users/sara/connections/omar')));
      await assertFails(getDoc(doc(mona(), 'users/sara/connections/omar')));
      await assertFails(getDoc(doc(nobody(), 'users/sara/connections/omar')));
      await assertFails(getDocs(collection(mona(), 'users/sara/connections')));
      await assertFails(getDocs(collection(omar(), 'users/sara/connections')));
      await assertFails(getDocs(collection(nobody(), 'users/sara/connections')));
      await assertSucceeds(getDocs(collection(sara(), 'users/sara/connections')));
    });

    test('a nickname is the owner\'s alone, and only that can change', async () => {
      await connected();
      await assertSucceeds(updateDoc(doc(sara(), 'users/sara/connections/omar'), { nickname: 'Brother' }));
      await assertFails(updateDoc(doc(omar(), 'users/sara/connections/omar'), { nickname: 'Boss' }));
      await assertFails(updateDoc(doc(sara(), 'users/sara/connections/omar'), { contactName: 'Someone' }));
      await assertFails(updateDoc(doc(sara(), 'users/sara/connections/omar'), { permissions: { safetyAlerts: true } }));
      await assertFails(updateDoc(doc(sara(), 'users/sara/connections/omar'), { nickname: 'x'.repeat(61) }));
    });

    test('either side ends it; a third account cannot', async () => {
      await connected();
      await assertFails(updateDoc(doc(mona(), 'users/sara/connections/omar'), ended('mona')));
      await assertFails(updateDoc(doc(nobody(), 'users/sara/connections/omar'), ended('omar')));
      await assertFails(updateDoc(doc(omar(), 'users/sara/connections/omar'), ended('sara')));
      await assertFails(updateDoc(doc(omar(), 'users/sara/connections/omar'), { ...ended('omar'), revokedAt: Timestamp.now() }));
      await assertFails(updateDoc(doc(omar(), 'users/sara/connections/omar'), { ...ended('omar'), contactName: 'Someone' }));
      await assertSucceeds(updateDoc(doc(omar(), 'users/sara/connections/omar'), ended('omar')));
      await assertSucceeds(updateDoc(doc(omar(), 'users/omar/connections/sara'), ended('omar')));
    });

    test('ending it removes the ender\'s copy and tells the other side, in one write', async () => {
      await connected();
      const db = sara();
      const batch = writeBatch(db);
      batch.update(doc(db, 'users/omar/connections/sara'), ended('sara'));
      batch.delete(doc(db, 'users/sara/connections/omar'));
      await assertSucceeds(batch.commit());
    });

    test('a copy cannot be dropped while the other side still thinks it is on', async () => {
      await connected();
      await assertFails(deleteDoc(doc(sara(), 'users/sara/connections/omar')));
      await assertFails(deleteDoc(doc(omar(), 'users/sara/connections/omar')));
    });

    test('the other account being gone frees this side', async () => {
      await connected();
      await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'users/omar/connections/sara')));
      await assertSucceeds(deleteDoc(doc(sara(), 'users/sara/connections/omar')));
    });

    test('an ended connection is never switched back on by a plain write', async () => {
      await connected();
      await assertSucceeds(updateDoc(doc(omar(), 'users/sara/connections/omar'), ended('omar')));
      await assertSucceeds(updateDoc(doc(omar(), 'users/omar/connections/sara'), ended('omar')));
      await assertFails(updateDoc(doc(sara(), 'users/sara/connections/omar'), { status: 'accepted' }));
      await assertFails(updateDoc(doc(omar(), 'users/omar/connections/sara'), { status: 'accepted' }));
      await assertFails(setDoc(doc(omar(), 'users/omar/connections/sara'), record('omar', 'sara', 'Sara Ahmed')));
      await assertFails(updateDoc(doc(sara(), 'users/sara/connections/omar'), { nickname: 'Brother' }));
    });

    test('a new invite can bring it back, and only that', async () => {
      await connected();
      await assertSucceeds(updateDoc(doc(omar(), 'users/sara/connections/omar'), ended('omar')));
      await assertSucceeds(updateDoc(doc(omar(), 'users/omar/connections/sara'), ended('omar')));
      await seed(`connectionInvites/${token}`, { ...newInvite(), createdAt: made });
      await assertSucceeds(accept(omar()));
    });

    test('connecting twice is refused', async () => {
      await connected();
      await seed(`connectionInvites/${token}`, { ...newInvite(), createdAt: made });
      await assertFails(accept(omar()));
    });
  });

  describe('what it does not open', () => {
    test('a connection reads nothing of the other account', async () => {
      await connected();
      const paths = [
        'users/sara',
        'users/sara/journeys/j1',
        'users/sara/journeys/j1/route/00000',
        'users/sara/journeys/j1/tracking/summary',
        'users/sara/contacts/c1',
        'users/sara/devices/d1',
        'users/sara/shares/s1',
        'users/sara/safetyChecks/s1',
        'users/sara/incidents/i1',
        'users/sara/escalations/e1',
        'users/sara/contactLinks/l1',
        'users/sara/receivedAlerts/a1',
      ];
      for (const path of paths) {
        if (path !== 'users/sara') await seed(path, { status: 'active' });
        await assertFails(getDoc(doc(omar(), path)));
      }
      await assertFails(getDocs(collection(omar(), 'users/sara/journeys')));
      await assertFails(getDocs(collection(omar(), 'users/sara/shares')));
    });

    test('nor does it open a share, or close one', async () => {
      await connected();
      const share = 'Shr_-0123456789Shr_-0123456789Shr_-01234567';
      const data = { kind: 'location', createdAt: Timestamp.now(), expiresAt: later(30), updatedAt: Timestamp.now(), tracking: 'live', routeChunks: 0, routeVersion: 0 };
      await seed(`users/sara/shares/${share}`, { kind: 'location', createdAt: Timestamp.now(), expiresAt: later(30) });
      await seed(`shares/${share}`, data);
      await assertFails(getDocs(collection(omar(), 'shares')));
      await assertFails(updateDoc(doc(omar(), `shares/${share}`), { tracking: 'paused', updatedAt: serverTimestamp() }));
      await assertFails(deleteDoc(doc(omar(), `shares/${share}`)));
      // Ending the connection changes nothing about the link.
      await assertSucceeds(updateDoc(doc(omar(), 'users/sara/connections/omar'), ended('omar')));
      await assertSucceeds(getDoc(doc(nobody(), `shares/${share}`)));
    });

    test('no rule outside a connection\'s own reads one', () => {
      const rules = readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8');
      const own = rules.slice(rules.indexOf('match /connections/{contactUid}'), rules.indexOf('// One per install that receives'));
      const invites = rules.slice(rules.indexOf('match /connectionInvites/{token}'), rules.indexOf('// Everything else'));
      const rest = rules.replace(own, '').replace(invites, '');
      assert.doesNotMatch(rest, /connections\//);
      assert.doesNotMatch(rest, /connectionInvites/);
    });

    test('the backend-only collections stay closed', async () => {
      await connected();
      for (const path of ['users/sara/contactLinks/c1', 'users/omar/receivedAlerts/a1', 'contactInvites/x']) {
        await assertFails(setDoc(doc(omar(), path), { status: 'accepted' }));
      }
    });
  });

  test('deleting an account ends its connections and its invites', async () => {
    await connected();
    await seed('connectionInvites/Old_-0123456789Old_-0123456789Old_-01234567', { ...newInvite(), createdAt: made });
    const db = sara();
    const mine = await assertSucceeds(getDocs(query(collection(db, 'connectionInvites'), where('inviterUid', '==', 'sara'))));
    const batch = writeBatch(db);
    batch.update(doc(db, 'users/omar/connections/sara'), ended('sara'));
    batch.delete(doc(db, 'users/sara/connections/omar'));
    mine.forEach((d) => batch.delete(d.ref));
    await assertSucceeds(batch.commit());
  });
});

describe('account deletion, from the phone', () => {
  test('the owner can remove everything the app deletes', async () => {
    const paths = [
      'users/sara/journeys/j1/checklists/preJourney',
      'users/sara/journeys/j1/route/00000',
      'users/sara/journeys/j1/tracking/summary',
      'users/sara/journeys/j1',
      'users/sara/contacts/c1',
      'users/sara/devices/d1',
      'users/sara',
    ];
    for (const path of paths) await seed(path, { status: 'completed' });
    for (const path of paths) await assertSucceeds(deleteDoc(doc(sara(), path)));
  });

  test('nobody else can', async () => {
    const paths = [
      'users/sara/journeys/j1',
      'users/sara/journeys/j1/route/00000',
      'users/sara/contacts/c1',
      'users/sara/devices/d1',
      'users/sara',
    ];
    for (const path of paths) {
      await seed(path, { status: 'completed' });
      await assertFails(deleteDoc(doc(omar(), path)));
      await assertFails(deleteDoc(doc(nobody(), path)));
    }
  });
});

describe('listing another account', () => {
  test('is refused for every collection', async () => {
    for (const name of ['journeys', 'contacts', 'devices', 'safetyChecks',
                        'incidents', 'escalations', 'contactLinks',
                        'receivedAlerts']) {
      await seed(`users/sara/${name}/x`, { status: 'completed' });
      await assertFails(getDocs(collection(omar(), `users/sara/${name}`)));
      await assertSucceeds(getDocs(collection(sara(), `users/sara/${name}`)));
    }
  });
});

describe('forged times and fields', () => {
  test('a contact\'s time is the server\'s', async () => {
    const past = Timestamp.fromDate(new Date(Date.now() - 60e3));
    const ref = doc(sara(), 'users/sara/contacts/c1');
    await assertFails(setDoc(ref, contact({ createdAt: past })));
    await assertFails(setDoc(ref, contact({ updatedAt: past })));
  });

  test('a device holds its three fields and no more', async () => {
    const ref = doc(sara(), 'users/sara/devices/install1');
    const data = { fid: 'fid-0123456789', platform: 'android', updatedAt: serverTimestamp() };
    await assertFails(setDoc(ref, { ...data, uid: 'omar' }));
    await assertFails(setDoc(ref, { ...data, fid: 'short' }));
  });
});

describe('what only the backend writes', () => {
  const paths = [
    'users/sara/escalations/e1-check',
    'users/sara/escalations/e1-check/attempts/c1',
    'users/sara/contactLinks/c1',
    'users/sara/receivedAlerts/a1',
  ];

  test('the owner reads it; nobody else does', async () => {
    for (const path of paths) {
      await seed(path, { status: 'completed' });
      await assertSucceeds(getDoc(doc(sara(), path)));
      await assertFails(getDoc(doc(omar(), path)));
      await assertFails(getDoc(doc(nobody(), path)));
    }
  });

  test('no client creates, changes or deletes it — the owner included', async () => {
    for (const path of paths) {
      await assertFails(setDoc(doc(sara(), path), { status: 'completed' }));
      await seed(path, { status: 'failed' });
      await assertFails(updateDoc(doc(sara(), path), { status: 'completed' }));
      await assertFails(deleteDoc(doc(sara(), path)));
      await assertFails(updateDoc(doc(omar(), path), { status: 'completed' }));
    }
  });

  test('an attempt cannot be marked delivered', async () => {
    const path = 'users/sara/escalations/e1-check/attempts/c1';
    await seed(path, { status: 'accepted', delivery: 'unknown' });
    await assertFails(updateDoc(doc(sara(), path), { delivery: 'delivered' }));
  });

  test('nobody makes themselves someone\'s contact', async () => {
    await assertFails(
      setDoc(doc(omar(), 'users/sara/contactLinks/c1'), { contactUid: 'omar' }),
    );
    await assertFails(
      setDoc(doc(sara(), 'users/omar/receivedAlerts/a1'), { fromName: 'x' }),
    );
  });

  test('invites are closed to every client', async () => {
    await seed('contactInvites/hash', { ownerUid: 'sara' });
    await assertFails(getDoc(doc(sara(), 'contactInvites/hash')));
    await assertFails(setDoc(doc(sara(), 'contactInvites/x'), { ownerUid: 'sara' }));
  });

  test('a link never rides on a contact', async () => {
    const ref = doc(sara(), 'users/sara/contacts/c1');
    await assertFails(setDoc(ref, contact({ contactUid: 'omar' })));
  });
});

describe('everything else', () => {
  test('is closed', async () => {
    await assertFails(setDoc(doc(sara(), 'incidents/i1'), { ownerUid: 'sara' }));
    await assertFails(getDoc(doc(sara(), 'anything/else')));
  });
});
