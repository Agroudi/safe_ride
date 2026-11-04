// Tests for firestore.rules — run with `npm test` in this folder (needs the
// Firebase CLI and JDK 21 for the emulator). Every rule the app relies on is
// checked from both sides: what the owner may do, and what nobody may.
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
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
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
