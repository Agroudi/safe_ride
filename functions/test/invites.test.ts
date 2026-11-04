import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { after, beforeEach, describe, it } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { eraseBackendData } from "../src/erase";
import {
  acceptInvite,
  createInvite,
  InviteError,
  inviteLifetimeMs,
} from "../src/invites";

const app = initializeApp({ projectId: "demo-saferide" }, "invites");
const db = getFirestore(app);
const t0 = new Date("2026-11-04T10:00:00.000Z");

const problem = (name: string) => (e: unknown) =>
  e instanceof InviteError && e.problem === name;

describe("contact invites", () => {
  beforeEach(async () => {
    await fetch(
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-saferide/databases/(default)/documents`,
      { method: "DELETE" },
    );
    await db.doc("users/sara").set({ fullName: "Sara Ali" });
    await db
      .doc("users/sara/contacts/c1")
      .set({ fullName: "Omar", phone: "+966500000002", phoneDigits: "966500" });
  });

  after(() => deleteApp(app));

  it("a deleted account leaves nothing behind for the backend", async () => {
    await createInvite(db, "sara", "c1", t0);
    await db.doc("users/sara/escalations/e1").set({ status: "completed" });
    await db.doc("users/sara/escalations/e1/attempts/c1").set({ status: "x" });
    await db.doc("users/sara/contactLinks/c1").set({ contactUid: "omar" });
    await db.doc("users/omar").set({ fullName: "Omar" });
    await eraseBackendData(db, "sara");
    assert.equal((await db.doc("users/sara/escalations/e1").get()).exists, false);
    assert.equal(
      (await db.doc("users/sara/escalations/e1/attempts/c1").get()).exists,
      false,
    );
    assert.equal((await db.collection("contactInvites").get()).size, 0);
    assert.equal((await db.doc("users/omar").get()).exists, true);
  });

  it("only another person's contact can be invited", async () => {
    await assert.rejects(
      createInvite(db, "omar", "c1", t0),
      problem("contactNotFound"),
    );
  });

  it("stores the code's hash, never the code", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    assert.match(code, /^[2-9A-Z]{5}-[2-9A-Z]{5}$/);
    const plain = code.replace("-", "");
    const stored = await db.collection("contactInvites").get();
    assert.equal(stored.size, 1);
    assert.equal(
      stored.docs[0].id,
      createHash("sha256").update(plain).digest("hex"),
    );
    assert.ok(!JSON.stringify(stored.docs[0].data()).includes(plain));
  });

  it("accepting links the contact, once", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    const { ownerName } = await acceptInvite(db, "omar", code, t0);
    assert.equal(ownerName, "Sara Ali");
    const link = (await db.doc("users/sara/contactLinks/c1").get()).data();
    assert.equal(link?.contactUid, "omar");
    assert.equal(link?.phoneDigits, "966500");
    await assert.rejects(acceptInvite(db, "lina", code, t0), problem("used"));
  });

  it("typed loosely, it still works", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    const typed = ` ${code.toLowerCase().replace("-", " ")} `;
    await acceptInvite(db, "omar", typed, t0);
    assert.ok((await db.doc("users/sara/contactLinks/c1").get()).exists);
  });

  it("an unknown code is refused", async () => {
    await assert.rejects(
      acceptInvite(db, "omar", "AAAAA-BBBBB", t0),
      problem("invalidCode"),
    );
  });

  it("an expired code is refused", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    const late = new Date(t0.getTime() + inviteLifetimeMs);
    await assert.rejects(acceptInvite(db, "omar", code, late), problem("expired"));
  });

  it("nobody accepts their own invite", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    await assert.rejects(acceptInvite(db, "sara", code, t0), problem("ownInvite"));
  });

  it("a contact whose number changed cannot be linked by the old code", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    await db.doc("users/sara/contacts/c1").update({ phoneDigits: "111" });
    await assert.rejects(acceptInvite(db, "omar", code, t0), problem("expired"));
  });

  it("a contact deleted meanwhile cannot be linked", async () => {
    const { code } = await createInvite(db, "sara", "c1", t0);
    await db.doc("users/sara/contacts/c1").delete();
    await assert.rejects(acceptInvite(db, "omar", code, t0), problem("expired"));
  });
});
