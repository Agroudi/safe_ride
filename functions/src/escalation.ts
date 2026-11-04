import { Firestore, Timestamp } from "firebase-admin/firestore";
import { Alert, AlertChannel, Device } from "./channel";
import { Data, RecentEscalation, rejectionOf } from "./eligibility";
import { alertText, Locale } from "./messages";

export interface Deps {
  db: Firestore;
  channel: AlertChannel;
  now(): Date;

  /** False when the account was deleted or disabled. */
  accountUsable(uid: string): Promise<boolean>;
}

export const Retry = {
  /** Waits after the first, second and third failed send. */
  backoffMs: [60_000, 5 * 60_000, 15 * 60_000],

  /** A send still claimed after this crashed; it may go again. */
  leaseMs: 2 * 60_000,

  /** The scheduled sweep picks up a dispatch that stopped half way. */
  watchdogMs: 10 * 60_000,
} as const;

type AttemptStatus = "sending" | "accepted" | "retryScheduled" | "failed";

interface Recipient {
  contactId: string;
  contactUid: string;
  locale: Locale;
  devices: Device[];
}

const escalationPath = (uid: string, id: string) =>
  `users/${uid}/escalations/${id}`;

const stamp = (d: Date) => Timestamp.fromDate(d);

/**
 * Handles one escalation request: the safety check the phone wrote. Safe to
 * run any number of times, from any number of phones and retries — the
 * escalation's id *is* the safety check's id, and it is created in a
 * transaction, so one check can only ever make one escalation.
 */
export async function processRequest(
  deps: Deps,
  uid: string,
  checkId: string,
): Promise<void> {
  const accountUsable = await deps.accountUsable(uid);
  const status = await claim(deps, uid, checkId, accountUsable);
  if (status === "dispatching") await dispatch(deps, uid, checkId);
}

/** Creates the one escalation record, or finds it. Returns its status. */
async function claim(
  deps: Deps,
  uid: string,
  checkId: string,
  accountUsable: boolean,
): Promise<string> {
  const { db } = deps;
  const user = `users/${uid}`;
  const ref = db.doc(escalationPath(uid, checkId));
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return existing.get("status") as string;

    const now = deps.now();
    const check = (
      await tx.get(db.doc(`${user}/safetyChecks/${checkId}`))
    ).data();
    const incidentId = check?.incidentId;
    const journeyId = check?.journeyId;
    const valid = isDocumentId(incidentId) && isDocumentId(journeyId);
    const incident = valid
      ? (await tx.get(db.doc(`${user}/incidents/${incidentId}`))).data()
      : undefined;
    const journey = valid
      ? (await tx.get(db.doc(`${user}/journeys/${journeyId}`))).data()
      : undefined;
    const since = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const recent = await tx.get(
      db
        .collection(`${user}/escalations`)
        .where("createdAt", ">=", stamp(since)),
    );

    const rejection = rejectionOf({
      uid,
      checkId,
      now,
      accountUsable,
      check: valid ? check : undefined,
      incident,
      journey,
      recent: recent.docs.map(
        (d): RecentEscalation => ({
          journeyId: d.get("journeyId"),
          status: d.get("status"),
          createdAt: (d.get("createdAt") as Timestamp).toDate(),
        }),
      ),
    });
    const status = rejection === null ? "dispatching" : "rejected";
    tx.create(ref, {
      safetyCheckId: checkId,
      incidentId: valid ? incidentId : null,
      journeyId: valid ? journeyId : null,
      uid,
      status,
      reason: rejection,
      type: incident?.type ?? null,
      // When it happened, when the phone's request reached the server, and
      // when this record was made: three different moments after an offline
      // stretch.
      eventAt: check?.timedOutAt ?? null,
      requestedAt: check?.syncedAt ?? null,
      createdAt: stamp(now),
      dispatchedAt: null,
      finishedAt: rejection === null ? null : stamp(now),
      nextRetryAt:
        rejection === null
          ? stamp(new Date(now.getTime() + Retry.watchdogMs))
          : null,
      recipients: 0,
      accepted: 0,
      failed: 0,
    });
    return status;
  });
}

function isDocumentId(id: unknown): id is string {
  return typeof id === "string" && id.length > 0 && !id.includes("/");
}

/** Sends what is due to every contact who can receive it, and records it. */
export async function dispatch(
  deps: Deps,
  uid: string,
  id: string,
): Promise<void> {
  const { db } = deps;
  const ref = db.doc(escalationPath(uid, id));
  const escalation = (await ref.get()).data();
  if (
    escalation === undefined ||
    !["dispatching", "retrying"].includes(escalation.status)
  ) {
    return;
  }
  const profile = (await db.doc(`users/${uid}`).get()).data() ?? {};
  const { total, recipients } = await resolve(deps, uid);
  if (recipients.length === 0) {
    await ref.update({
      status: "noRecipients",
      reason: total === 0 ? "noContacts" : "noReachableContact",
      nextRetryAt: null,
      finishedAt: stamp(deps.now()),
    });
    return;
  }
  await ref.update({
    dispatchedAt: escalation.dispatchedAt ?? stamp(deps.now()),
    recipients: recipients.length,
  });
  for (const r of recipients) {
    await attempt(deps, uid, id, escalation, profile, r);
  }
  await settle(deps, uid, id);
}

/**
 * The contacts who can actually be reached: linked (they accepted this
 * user's invite), the link still for this number, their account usable,
 * and at least one registered phone. A contact deleted from the list is
 * gone from here too.
 */
async function resolve(
  deps: Deps,
  uid: string,
): Promise<{ total: number; recipients: Recipient[] }> {
  const { db } = deps;
  const contacts = await db.collection(`users/${uid}/contacts`).get();
  const recipients: Recipient[] = [];
  for (const contact of contacts.docs) {
    const link = (
      await db.doc(`users/${uid}/contactLinks/${contact.id}`).get()
    ).data();
    if (link === undefined || link.phoneDigits !== contact.get("phoneDigits")) {
      continue;
    }
    const contactUid = link.contactUid as string;
    if (!(await deps.accountUsable(contactUid))) continue;
    const devices = await db.collection(`users/${contactUid}/devices`).get();
    if (devices.empty) continue;
    const profile = await db.doc(`users/${contactUid}`).get();
    recipients.push({
      contactId: contact.id,
      contactUid,
      locale: profile.get("locale") === "ar" ? "ar" : "en",
      devices: devices.docs.map((d) => ({
        installId: d.id,
        fid: d.get("fid") as string,
      })),
    });
  }
  return { total: contacts.size, recipients };
}

/** One send to one contact, claimed first so two runs never send together. */
async function attempt(
  deps: Deps,
  uid: string,
  id: string,
  escalation: Data,
  profile: Data,
  r: Recipient,
): Promise<void> {
  const { db, channel } = deps;
  const ref = db.doc(`${escalationPath(uid, id)}/attempts/${r.contactId}`);
  const tries = await db.runTransaction(async (tx) => {
    const now = deps.now();
    const current = (await tx.get(ref)).data();
    const status = current?.status as AttemptStatus | undefined;
    if (status === "accepted" || status === "failed") return null;
    const held = current?.notBefore as Timestamp | null | undefined;
    if (held && held.toDate() > now) return null;
    const count = ((current?.tries as number | undefined) ?? 0) + 1;
    tx.set(
      ref,
      {
        contactId: r.contactId,
        channel: channel.name,
        status: "sending",
        tries: count,
        lastAttemptAt: stamp(now),
        notBefore: stamp(new Date(now.getTime() + Retry.leaseMs)),
      },
      { merge: true },
    );
    return count;
  });
  if (tries === null) return;

  const name = (profile.fullName as string | undefined) ?? "";
  const eventAt = (escalation.eventAt as Timestamp).toDate();
  // The contact's own copy first: it is what the notification opens, and
  // it holds only what they were authorised to see. No location.
  await db.doc(`users/${r.contactUid}/receivedAlerts/${uid}_${id}`).set({
    fromName: name,
    fromPhone: (profile.phone as string | undefined) ?? null,
    type: escalation.type,
    eventAt: stamp(eventAt),
    createdAt: stamp(deps.now()),
  });
  const text = alertText(r.locale, { name, type: escalation.type, eventAt });
  const alert: Alert = { key: `alert_${id}`, ...text };
  const result = await channel.send(r.devices, alert);

  const now = deps.now();
  if (result.outcome !== "retry") {
    for (const device of result.staleDevices) {
      await db.doc(`users/${r.contactUid}/devices/${device}`).delete();
    }
  }
  if (result.outcome === "accepted") {
    await ref.update({
      status: "accepted",
      // FCM says nothing about what happened after it took the request.
      delivery: "unknown",
      providerIds: result.providerIds,
      acceptedAt: stamp(now),
      failure: null,
      notBefore: null,
    });
  } else if (result.outcome === "retry" && tries <= Retry.backoffMs.length) {
    await ref.update({
      status: "retryScheduled",
      failure: result.code,
      notBefore: stamp(new Date(now.getTime() + Retry.backoffMs[tries - 1])),
    });
  } else {
    await ref.update({
      status: "failed",
      failure: result.code,
      notBefore: null,
    });
  }
}

/** Sums the attempts into the escalation's status. */
async function settle(deps: Deps, uid: string, id: string): Promise<void> {
  const ref = deps.db.doc(escalationPath(uid, id));
  const attempts = await ref.collection("attempts").get();
  const of = (s: AttemptStatus) =>
    attempts.docs.filter((d) => d.get("status") === s);
  const accepted = of("accepted").length;
  const failed = of("failed").length;
  const waiting = [...of("retryScheduled"), ...of("sending")];
  if (waiting.length > 0) {
    const next = waiting
      .map((d) => (d.get("notBefore") as Timestamp).toMillis())
      .reduce((a, b) => Math.min(a, b));
    await ref.update({
      status: "retrying",
      accepted,
      failed,
      nextRetryAt: Timestamp.fromMillis(next),
    });
    return;
  }
  await ref.update({
    status: accepted > 0 ? "completed" : "failed",
    accepted,
    failed,
    nextRetryAt: null,
    finishedAt: stamp(deps.now()),
  });
}

/** The scheduled sweep: every escalation with a send due, or stopped. */
export async function retryDue(deps: Deps): Promise<number> {
  const due = await deps.db
    .collectionGroup("escalations")
    .where("status", "in", ["dispatching", "retrying"])
    .where("nextRetryAt", "<=", stamp(deps.now()))
    .limit(50)
    .get();
  for (const d of due.docs) {
    await dispatch(deps, d.get("uid") as string, d.id);
  }
  return due.size;
}
