import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import { FcmChannel } from "../src/channel";
import { InviteError } from "../src/invites";
import { alertText } from "../src/messages";
import {
  accountUsable,
  answering,
  signedInUid,
  textField,
} from "../src/requests";

const eventAt = new Date("2026-11-04T07:05:00.000Z");
const device = { installId: "i1", fid: "f1" };
const alert = { key: "alert_x", title: "t", body: "b" };

describe("what a contact reads", () => {
  for (const locale of ["en", "ar"] as const) {
    for (const type of ["suddenDeceleration", "prolongedStop"]) {
      it(`${locale} ${type}: only what SafeRide knows`, () => {
        const { title, body } = alertText(locale, {
          name: "Sara",
          type,
          eventAt,
        });
        const text = `${title} ${body}`;
        assert.ok(text.includes("Sara"));
        for (const claim of [
          /accident/i,
          /injur/i,
          /crash/i,
          /حادث/,
          /إصاب/,
          /مصاب/,
        ]) {
          assert.doesNotMatch(text, claim);
        }
        assert.match(
          text,
          locale === "en"
            ? /hasn't contacted emergency services/
            : /لم يتصل\s+SafeRide بخدمات الطوارئ/,
        );
        assert.doesNotMatch(text, /-?\d{1,3}\.\d{3,}/, "no coordinates");
      });
    }
  }

  it("says which event, and when", () => {
    const en = alertText("en", { name: "S", type: "prolongedStop", eventAt });
    assert.match(en.body, /a long stop/);
    assert.match(en.body, /07:05 UTC/);
    const ar = alertText("ar", {
      name: "S",
      type: "suddenDeceleration",
      eventAt,
    });
    assert.match(ar.body, /تباطؤ مفاجئ/);
    assert.ok(ar.body.includes("٠٧:٠٥"));
  });
});

describe("FCM", () => {
  const answering_ = (responses: unknown[]) => ({
    sendEach: async () => ({ responses }) as never,
  });

  it("addresses installs by FID, and replaces rather than stacks", async () => {
    let sent: Record<string, unknown>[] = [];
    const channel = new FcmChannel({
      sendEach: async (messages) => {
        sent = messages as never;
        return {
          responses: [{ success: true, messageId: "m1" }],
          successCount: 1,
          failureCount: 0,
        };
      },
    });
    const result = await channel.send([device], alert);
    assert.deepEqual(result, {
      outcome: "accepted",
      providerIds: ["m1"],
      staleDevices: [],
    });
    assert.equal(sent[0].fid, "f1");
    assert.deepEqual(sent[0].data, { route: "safety-alerts" });
    const android = sent[0].android as Record<string, Record<string, string>>;
    assert.equal(android.notification.tag, "alert_x");
  });

  it("any install accepting counts; dead ones are named", async () => {
    const channel = new FcmChannel(
      answering_([
        { success: true, messageId: "m1" },
        {
          success: false,
          error: { code: "messaging/registration-token-not-registered" },
        },
      ]),
    );
    const result = await channel.send(
      [device, { installId: "i2", fid: "f2" }],
      alert,
    );
    assert.deepEqual(result, {
      outcome: "accepted",
      providerIds: ["m1"],
      staleDevices: ["i2"],
    });
  });

  it("a passing error retries; a dead device does not", async () => {
    const passing = new FcmChannel(
      answering_([
        { success: false, error: { code: "messaging/internal-error" } },
      ]),
    );
    assert.equal((await passing.send([device], alert)).outcome, "retry");
    const gone = new FcmChannel(
      answering_([
        {
          success: false,
          error: { code: "messaging/registration-token-not-registered" },
        },
      ]),
    );
    assert.deepEqual(await gone.send([device], alert), {
      outcome: "failed",
      code: "messaging/registration-token-not-registered",
      staleDevices: ["i1"],
    });
  });

  it("the network failing is a retry", async () => {
    const channel = new FcmChannel({
      sendEach: async () => {
        throw Object.assign(new Error("x"), { code: "app/network-error" });
      },
    });
    assert.deepEqual(await channel.send([device], alert), {
      outcome: "retry",
      code: "app/network-error",
    });
  });
});

describe("requests", () => {
  it("no token, no caller", () => {
    assert.throws(
      () => signedInUid({ auth: undefined }),
      (e: HttpsError) => e.code === "unauthenticated",
    );
  });

  it("the uid is the token's, whatever the body says", () => {
    const request = {
      auth: { uid: "sara", token: {} as never, rawToken: "" },
      data: { uid: "omar" },
    };
    assert.equal(signedInUid(request), "sara");
  });

  it("refuses a field that is missing, not text, or a path", () => {
    for (const data of [null, {}, { c: 1 }, { c: "" }, { c: "a/b" }]) {
      assert.throws(
        () => textField({ data }, "c"),
        (e: HttpsError) => e.code === "invalid-argument",
      );
    }
    assert.equal(textField({ data: { c: "ok" } }, "c"), "ok");
  });

  it("a disabled or deleted account is not usable", async () => {
    const auth = (disabled: boolean) => ({
      getUser: async () => ({ disabled }) as never,
    });
    assert.equal(await accountUsable(auth(false), "x"), true);
    assert.equal(await accountUsable(auth(true), "x"), false);
    const gone = {
      getUser: async () => {
        throw Object.assign(new Error("x"), { code: "auth/user-not-found" });
      },
    };
    assert.equal(await accountUsable(gone, "x"), false);
  });

  it("a passing Auth failure is not mistaken for a closed account", async () => {
    const failing = {
      getUser: async () => {
        throw Object.assign(new Error("x"), { code: "auth/internal-error" });
      },
    };
    await assert.rejects(accountUsable(failing, "x"));
  });

  it("invite problems reach the app by code, never as not-found", async () => {
    const codes = await Promise.all(
      (["invalidCode", "expired", "used", "ownInvite", "contactNotFound"] as const).map(
        (p) =>
          answering(async () => {
            throw new InviteError(p);
          }).catch((e: HttpsError) => e.code),
      ),
    );
    assert.deepEqual(codes, [
      "invalid-argument",
      "failed-precondition",
      "failed-precondition",
      "permission-denied",
      "failed-precondition",
    ]);
  });
});
