import { Firestore } from "firebase-admin/firestore";

/**
 * What the app cannot delete for a deleted account: everything left under
 * `users/{uid}` (escalations, attempts, links, alerts received, requests) and
 * the invites it made. Safety records are not kept past the account: no law
 * or audit need has been identified for them; revisit that before launch.
 */
export async function eraseBackendData(
  db: Firestore,
  uid: string,
): Promise<void> {
  await db.recursiveDelete(db.doc(`users/${uid}`));
  const invites = await db
    .collection("contactInvites")
    .where("ownerUid", "==", uid)
    .get();
  await Promise.all(invites.docs.map((d) => d.ref.delete()));
}
