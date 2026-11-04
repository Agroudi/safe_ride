import { createHash, randomInt } from "node:crypto";
import { Firestore, Timestamp } from "firebase-admin/firestore";

/** Why an invite could not be used; `index.ts` maps each to an error code. */
export type InviteProblem =
  | "contactNotFound"
  | "invalidCode"
  | "expired"
  | "used"
  | "ownInvite";

export class InviteError extends Error {
  constructor(readonly problem: InviteProblem) {
    super(problem);
  }
}

/** Long enough to read aloud; 32^10 is far beyond guessing in three days. */
const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
const codeLength = 10;
export const inviteLifetimeMs = 72 * 60 * 60 * 1000;

const hash = (code: string) => createHash("sha256").update(code).digest("hex");

/** Upper case, without the separator or spaces a person may type. */
const normalize = (code: string) =>
  code.toUpperCase().replace(/[^0-9A-Z]/g, "");

/**
 * Makes a one-time code for one of [uid]'s contacts. The code itself is
 * returned once and never stored: only its hash is, so reading the
 * database gives no one a usable invite.
 */
export async function createInvite(
  db: Firestore,
  uid: string,
  contactId: string,
  now: Date,
): Promise<{ code: string; expiresAt: string }> {
  const contact = await db.doc(`users/${uid}/contacts/${contactId}`).get();
  if (!contact.exists) throw new InviteError("contactNotFound");
  let code = "";
  for (let i = 0; i < codeLength; i++) {
    code += alphabet[randomInt(alphabet.length)];
  }
  const expiresAt = new Date(now.getTime() + inviteLifetimeMs);
  await db.doc(`contactInvites/${hash(code)}`).create({
    ownerUid: uid,
    contactId,
    phoneDigits: contact.get("phoneDigits"),
    createdAt: Timestamp.fromDate(now),
    expiresAt: Timestamp.fromDate(expiresAt),
    usedAt: null,
  });
  return {
    code: `${code.slice(0, 5)}-${code.slice(5)}`,
    expiresAt: expiresAt.toISOString(),
  };
}

/**
 * [uid] accepts an invite: they become the contact it was made for. The
 * link is what lets alerts reach them, and only the server writes it — so
 * nobody can make themselves someone's contact by typing a phone number.
 */
export async function acceptInvite(
  db: Firestore,
  uid: string,
  code: string,
  now: Date,
): Promise<{ ownerName: string }> {
  const ref = db.doc(`contactInvites/${hash(normalize(code))}`);
  return db.runTransaction(async (tx) => {
    const invite = (await tx.get(ref)).data();
    if (invite === undefined) throw new InviteError("invalidCode");
    if (invite.usedAt !== null) throw new InviteError("used");
    if ((invite.expiresAt as Timestamp).toDate() <= now) {
      throw new InviteError("expired");
    }
    const owner = invite.ownerUid as string;
    if (owner === uid) throw new InviteError("ownInvite");
    const contactId = invite.contactId as string;
    const contact = await tx.get(
      db.doc(`users/${owner}/contacts/${contactId}`),
    );
    if (!contact.exists || contact.get("phoneDigits") !== invite.phoneDigits) {
      throw new InviteError("expired");
    }
    const profile = await tx.get(db.doc(`users/${owner}`));
    tx.set(db.doc(`users/${owner}/contactLinks/${contactId}`), {
      contactUid: uid,
      phoneDigits: invite.phoneDigits,
      linkedAt: Timestamp.fromDate(now),
    });
    tx.update(ref, { usedAt: Timestamp.fromDate(now) });
    return { ownerName: (profile.get("fullName") as string | undefined) ?? "" };
  });
}
