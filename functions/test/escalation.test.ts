import assert from "node:assert/strict";
import { after, beforeEach, describe, it } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { Alert, AlertChannel, Device, SendResult } from "../src/channel";
import { Limits } from "../src/eligibility";
import { Deps, dispatch, processRequest, Retry, retryDue } from "../src/escalation";

const app = initializeApp({ projectId: "demo-saferide" }, "escalation");
const db = getFirestore(app);

const t0 = new Date("2026-11-04T10:00:00.000Z");
const stamp = (d: Date) => Timestamp.fromDate(d);

/** A provider that records every send and answers what the test decides. */
class FakeChannel implements AlertChannel {
  readonly name = "fcm";
  sends: { devices: Device[]; alert: Alert }[] = [];
  answers: SendResult[] = [];

  async send(devices: Device[], alert: Alert): Promise<SendResult> {
    this.sends.push({ devices, alert });
    return (
      this.answers.shift() ?? {
        outcome: "accepted",
        providerIds: [`projects/x/messages/${this.sends.length}`],
        staleDevices: [],
      }
    );
  }
}

let now: Date;
let channel: FakeChannel;
let closedAccounts: Set<string>;
let deps: Deps;

async function clear(): Promise<void> {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-saferide/databases/(default)/documents`,
    { method: "DELETE" },
  );
}

async function seedRequest(
  uid = "sara",
  id = "e1-check",
  journeyId = "j1",
  overrides: Record<string, unknown> = {},
): Promise<void> {
  await db.doc(`users/${uid}`).set({ fullName: "Sara Ali", phone: "+966500000001" });
  await db.doc(`users/${uid}/journeys/${journeyId}`).set({ status: "active" });
  await db.doc(`users/${uid}/incidents/${id}-i`).set({
    journeyId,
    safetyCheckId: id,
    type: "prolongedStop",
    confidence: "medium",
  });
  await db.doc(`users/${uid}/safetyChecks/${id}`).set({
    uid,
    journeyId,
    incidentId: `${id}-i`,
    status: "escalationReady",
    deadline: stamp(new Date(t0.getTime() - 1000)),
    timedOutAt: stamp(new Date(t0.getTime() - 1000)),
    syncedAt: stamp(t0),
    ...overrides,
  });
}

/** A contact of [uid] who accepted the invite and has one phone. */
async function seedLinked(
  uid = "sara",
  contactId = "c1",
  contactUid = "omar",
  locale = "en",
): Promise<void> {
  await db
    .doc(`users/${uid}/contacts/${contactId}`)
    .set({ fullName: "Omar", phone: "+966500000002", phoneDigits: `9665${contactId}` });
  await db
    .doc(`users/${uid}/contactLinks/${contactId}`)
    .set({ contactUid, phoneDigits: `9665${contactId}`, linkedAt: stamp(t0) });
  await db.doc(`users/${contactUid}`).set({ fullName: "Omar", locale });
  await db
    .doc(`users/${contactUid}/devices/install-${contactUid}`)
    .set({ fid: `fid-${contactUid}`, platform: "android" });
}

const escalation = async (uid = "sara", id = "e1-check") =>
  (await db.doc(`users/${uid}/escalations/${id}`).get()).data();

const attemptOf = async (contact = "c1", id = "e1-check") =>
  (await db.doc(`users/sara/escalations/${id}/attempts/${contact}`).get()).data();

describe("escalation", () => {
  beforeEach(async () => {
    await clear();
    now = t0;
    channel = new FakeChannel();
    closedAccounts = new Set<string>();
    deps = {
      db,
      channel,
      now: () => now,
      accountUsable: async (uid) => !closedAccounts.has(uid),
    };
  });

  after(() => deleteApp(app));

  it("one eligible request alerts a linked contact and records it", async () => {
    await seedRequest();
    await seedLinked();
    await processRequest(deps, "sara", "e1-check");

    assert.equal(channel.sends.length, 1);
    assert.equal(channel.sends[0].devices[0].fid, "fid-omar");
    const e = await escalation();
    assert.equal(e?.status, "completed");
    assert.equal(e?.safetyCheckId, "e1-check");
    assert.equal(e?.incidentId, "e1-check-i");
    assert.equal(e?.journeyId, "j1");
    assert.equal(e?.uid, "sara");
    assert.equal(e?.recipients, 1);
    assert.equal(e?.accepted, 1);
    assert.ok(e?.dispatchedAt);
    assert.ok(e?.finishedAt);
    const a = await attemptOf();
    assert.equal(a?.status, "accepted");
    assert.equal(a?.delivery, "unknown", "accepted is never delivered");
    assert.deepEqual(a?.providerIds, ["projects/x/messages/1"]);
  });

  it("keeps the event's own time apart from the sync and dispatch", async () => {
    await seedRequest("sara", "e1-check", "j1", {
      timedOutAt: stamp(new Date(t0.getTime() - 3 * 3600_000)),
      deadline: stamp(new Date(t0.getTime() - 3 * 3600_000)),
    });
    await seedLinked();
    await processRequest(deps, "sara", "e1-check");
    const e = await escalation();
    assert.equal(e?.eventAt.toMillis(), t0.getTime() - 3 * 3600_000);
    assert.equal(e?.requestedAt.toMillis(), t0.getTime());
    assert.equal(e?.dispatchedAt.toMillis(), t0.getTime());
  });

  it("the contact's copy holds no location and no route", async () => {
    await seedRequest();
    await seedLinked();
    await processRequest(deps, "sara", "e1-check");
    const copy = (
      await db.doc("users/omar/receivedAlerts/sara_e1-check").get()
    ).data();
    assert.deepEqual(Object.keys(copy ?? {}).sort(), [
      "createdAt",
      "eventAt",
      "fromName",
      "fromPhone",
      "type",
    ]);
    assert.equal(copy?.fromName, "Sara Ali");
  });

  describe("duplicates", () => {
    it("a Cloud Function retry sends nothing twice", async () => {
      await seedRequest();
      await seedLinked();
      await processRequest(deps, "sara", "e1-check");
      await processRequest(deps, "sara", "e1-check");
      await processRequest(deps, "sara", "e1-check");
      assert.equal(channel.sends.length, 1);
    });

    it("concurrent deliveries of one event make one escalation", async () => {
      await seedRequest();
      await seedLinked();
      await Promise.all(
        Array.from({ length: 6 }, () =>
          processRequest(deps, "sara", "e1-check"),
        ),
      );
      assert.equal(channel.sends.length, 1);
      const all = await db.collection("users/sara/escalations").get();
      assert.equal(all.size, 1);
    });

    it("a second phone's check for the same journey alerts nobody", async () => {
      await seedRequest("sara", "e1-check");
      await seedRequest("sara", "e2-check");
      await seedLinked();
      await processRequest(deps, "sara", "e1-check");
      now = new Date(t0.getTime() + 60_000);
      await processRequest(deps, "sara", "e2-check");
      assert.equal(channel.sends.length, 1);
      const second = await escalation("sara", "e2-check");
      assert.equal(second?.status, "rejected");
      assert.equal(second?.reason, "duplicateJourney");
    });

    it("the journey can alert again after the cooldown", async () => {
      await seedRequest("sara", "e1-check");
      await seedLinked();
      await processRequest(deps, "sara", "e1-check");
      now = new Date(t0.getTime() + Limits.journeyCooldownMs + 1000);
      await seedRequest("sara", "e2-check", "j1", {
        deadline: stamp(now),
        timedOutAt: stamp(now),
      });
      await processRequest(deps, "sara", "e2-check");
      assert.equal(channel.sends.length, 2);
    });

    it("an account is limited per day", async () => {
      await seedLinked();
      for (let i = 0; i < Limits.perAccountPerDay + 1; i++) {
        await seedRequest("sara", `e${i}-check`, `j${i}`);
        await processRequest(deps, "sara", `e${i}-check`);
      }
      assert.equal(channel.sends.length, Limits.perAccountPerDay);
      const last = await escalation("sara", `e${Limits.perAccountPerDay}-check`);
      assert.equal(last?.reason, "rateLimited");
    });
  });

  describe("eligibility", () => {
    const rejected = async (reason: string) => {
      await processRequest(deps, "sara", "e1-check");
      const e = await escalation();
      assert.equal(e?.status, "rejected");
      assert.equal(e?.reason, reason);
      assert.equal(channel.sends.length, 0);
    };

    it("no safety check", async () => {
      await seedLinked();
      await rejected("checkInvalid");
    });

    it("a check claiming another user's uid", async () => {
      await seedRequest("sara", "e1-check", "j1", { uid: "omar" });
      await seedLinked();
      await rejected("checkInvalid");
    });

    it("a check that is not escalation-ready", async () => {
      await seedRequest("sara", "e1-check", "j1", { status: "confirmedSafe" });
      await seedLinked();
      await rejected("notEscalationReady");
    });

    it("a deadline still ahead", async () => {
      await seedRequest("sara", "e1-check", "j1", {
        deadline: stamp(new Date(t0.getTime() + 5000)),
      });
      await seedLinked();
      await rejected("deadlineNotPassed");
    });

    it("an incident of another journey", async () => {
      await seedRequest();
      await seedLinked();
      await db
        .doc("users/sara/incidents/e1-check-i")
        .update({ journeyId: "other" });
      await rejected("incidentInvalid");
    });

    it("an incident pointing at another check", async () => {
      await seedRequest();
      await seedLinked();
      await db
        .doc("users/sara/incidents/e1-check-i")
        .update({ safetyCheckId: "other" });
      await rejected("incidentInvalid");
    });

    it("a tracking interruption is never escalated", async () => {
      await seedRequest();
      await seedLinked();
      await db
        .doc("users/sara/incidents/e1-check-i")
        .update({ type: "trackingInterrupted" });
      await rejected("incidentInvalid");
    });

    it("a low-confidence incident", async () => {
      await seedRequest();
      await seedLinked();
      await db
        .doc("users/sara/incidents/e1-check-i")
        .update({ confidence: "low" });
      await rejected("incidentInvalid");
    });

    it("an incident in another account does not count", async () => {
      await seedRequest();
      await seedLinked();
      const incident = db.doc("users/sara/incidents/e1-check-i");
      const copy = (await incident.get()).data()!;
      await incident.delete();
      await db.doc("users/omar/incidents/e1-check-i").set(copy);
      await rejected("incidentInvalid");
    });

    it("a journey that does not exist", async () => {
      await seedRequest();
      await seedLinked();
      await db.doc("users/sara/journeys/j1").delete();
      await rejected("journeyMissing");
    });

    it("a journey the user completed meanwhile", async () => {
      await seedRequest();
      await seedLinked();
      await db.doc("users/sara/journeys/j1").update({ status: "completed" });
      await rejected("journeyNotActive");
    });

    it("a request a day late", async () => {
      await seedRequest();
      await seedLinked();
      now = new Date(t0.getTime() + Limits.maxRequestAgeMs + 1000);
      await rejected("stale");
    });

    it("a disabled or deleted account", async () => {
      await seedRequest();
      await seedLinked();
      closedAccounts.add("sara");
      await rejected("accountUnavailable");
    });

    it("a malformed reference never reaches another path", async () => {
      await seedRequest("sara", "e1-check", "j1", {
        journeyId: "../../omar/journeys/j1",
      });
      await seedLinked();
      await rejected("checkInvalid");
    });
  });

  describe("recipients", () => {
    it("no trusted contacts: said so, nothing sent", async () => {
      await seedRequest();
      await processRequest(deps, "sara", "e1-check");
      const e = await escalation();
      assert.equal(e?.status, "noRecipients");
      assert.equal(e?.reason, "noContacts");
      assert.equal(channel.sends.length, 0);
    });

    it("a contact who never accepted an invite gets nothing", async () => {
      await seedRequest();
      await db
        .doc("users/sara/contacts/c1")
        .set({ fullName: "Omar", phone: "+966500000002", phoneDigits: "96650" });
      await processRequest(deps, "sara", "e1-check");
      const e = await escalation();
      assert.equal(e?.status, "noRecipients");
      assert.equal(e?.reason, "noReachableContact");
    });

    it("a contact whose number changed after linking gets nothing", async () => {
      await seedRequest();
      await seedLinked();
      await db.doc("users/sara/contacts/c1").update({ phoneDigits: "000" });
      await processRequest(deps, "sara", "e1-check");
      assert.equal((await escalation())?.status, "noRecipients");
      assert.equal(channel.sends.length, 0);
    });

    it("a contact deleted from the list gets nothing", async () => {
      await seedRequest();
      await seedLinked();
      await db.doc("users/sara/contacts/c1").delete();
      await processRequest(deps, "sara", "e1-check");
      assert.equal((await escalation())?.reason, "noContacts");
    });

    it("a contact with no registered phone gets nothing", async () => {
      await seedRequest();
      await seedLinked();
      await db.doc("users/omar/devices/install-omar").delete();
      await processRequest(deps, "sara", "e1-check");
      assert.equal((await escalation())?.reason, "noReachableContact");
    });

    it("a contact whose account closed gets nothing", async () => {
      await seedRequest();
      await seedLinked();
      closedAccounts.add("omar");
      await processRequest(deps, "sara", "e1-check");
      assert.equal((await escalation())?.status, "noRecipients");
    });

    it("each contact is told in their own language", async () => {
      await seedRequest();
      await seedLinked("sara", "c1", "omar", "ar");
      await seedLinked("sara", "c2", "lina", "en");
      await processRequest(deps, "sara", "e1-check");
      const titles = channel.sends.map((s) => s.alert.title).sort();
      assert.equal(titles.length, 2);
      assert.ok(titles[0].startsWith("Please check on"));
      assert.ok(titles[1].startsWith("يُرجى"));
    });

    it("one contact's data never reaches another account", async () => {
      await seedRequest();
      await seedLinked();
      await db.doc("users/lina").set({ fullName: "Lina" });
      await processRequest(deps, "sara", "e1-check");
      const others = await db.collection("users/lina/receivedAlerts").get();
      assert.equal(others.size, 0);
    });
  });

  describe("provider failures", () => {
    it("a passing failure schedules a retry, then the sweep sends", async () => {
      await seedRequest();
      await seedLinked();
      channel.answers = [{ outcome: "retry", code: "messaging/internal-error" }];
      await processRequest(deps, "sara", "e1-check");
      const waiting = await escalation();
      assert.equal(waiting?.status, "retrying");
      assert.equal(
        waiting?.nextRetryAt.toMillis(),
        t0.getTime() + Retry.backoffMs[0],
      );
      assert.equal((await attemptOf())?.status, "retryScheduled");
      assert.equal((await attemptOf())?.failure, "messaging/internal-error");

      assert.equal(await retryDue(deps), 0, "not due yet");
      now = new Date(t0.getTime() + Retry.backoffMs[0]);
      assert.equal(await retryDue(deps), 1);
      assert.equal(channel.sends.length, 2);
      assert.equal(channel.sends[0].alert.key, channel.sends[1].alert.key);
      assert.equal((await escalation())?.status, "completed");
      assert.equal((await attemptOf())?.tries, 2);
    });

    it("gives up after its retries and says failed", async () => {
      await seedRequest();
      await seedLinked();
      const code = "messaging/server-unavailable";
      channel.answers = Array.from({ length: 9 }, () => ({
        outcome: "retry" as const,
        code,
      }));
      await processRequest(deps, "sara", "e1-check");
      for (const wait of Retry.backoffMs) {
        now = new Date(now.getTime() + wait);
        await retryDue(deps);
      }
      assert.equal(channel.sends.length, Retry.backoffMs.length + 1);
      const e = await escalation();
      assert.equal(e?.status, "failed");
      assert.equal(e?.nextRetryAt, null);
      assert.equal((await attemptOf())?.failure, code);
    });

    it("a dead device is forgotten and not retried", async () => {
      await seedRequest();
      await seedLinked();
      channel.answers = [
        {
          outcome: "failed",
          code: "messaging/registration-token-not-registered",
          staleDevices: ["install-omar"],
        },
      ];
      await processRequest(deps, "sara", "e1-check");
      assert.equal((await escalation())?.status, "failed");
      const device = await db.doc("users/omar/devices/install-omar").get();
      assert.equal(device.exists, false);
    });

    it("one contact failing does not stop the next", async () => {
      await seedRequest();
      await seedLinked("sara", "c1", "omar");
      await seedLinked("sara", "c2", "lina");
      channel.answers = [
        { outcome: "failed", code: "messaging/unknown", staleDevices: [] },
      ];
      await processRequest(deps, "sara", "e1-check");
      assert.equal(channel.sends.length, 2);
      const e = await escalation();
      assert.equal(e?.status, "completed");
      assert.equal(e?.accepted, 1);
      assert.equal(e?.failed, 1);
    });

    it("a dispatch that crashed after claiming goes again later", async () => {
      await seedRequest();
      await seedLinked();
      const crashing = {
        ...deps,
        channel: {
          name: "fcm",
          send: async () => {
            throw new Error("crash");
          },
        },
      };
      await assert.rejects(processRequest(crashing, "sara", "e1-check"));
      assert.equal((await attemptOf())?.status, "sending");

      // The trigger's own retry, at once: the claim still holds.
      await processRequest(deps, "sara", "e1-check");
      assert.equal(channel.sends.length, 0);

      // The sweep, once the watchdog is due and the claim has lapsed.
      now = new Date(t0.getTime() + Retry.watchdogMs);
      assert.equal(await retryDue(deps), 1);
      assert.equal(channel.sends.length, 1);
      assert.equal((await escalation())?.status, "completed");
    });

    it("a finished escalation is left alone", async () => {
      await seedRequest();
      await seedLinked();
      await processRequest(deps, "sara", "e1-check");
      await dispatch(deps, "sara", "e1-check");
      assert.equal(channel.sends.length, 1);
    });
  });
});
