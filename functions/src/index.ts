import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { region } from "firebase-functions/v1";
import { FcmChannel } from "./channel";
import { eraseBackendData } from "./erase";
import { Deps, processRequest, retryDue } from "./escalation";
import { acceptInvite, createInvite } from "./invites";
import { accountUsable, answering, signedInUid, textField } from "./requests";

initializeApp();

// Firestore triggers must run where the database is (Dammam).
setGlobalOptions({ region: "me-central2", maxInstances: 5 });

const deps = (): Deps => ({
  db: getFirestore(),
  channel: new FcmChannel(getMessaging()),
  now: () => new Date(),
  accountUsable: (uid) => accountUsable(getAuth(), uid),
});

/**
 * A phone wrote an unanswered safety check. Firestore's rules already tied
 * the write to its owner; `retry` re-runs this after a crash, which the
 * transaction in `processRequest` makes harmless.
 */
export const onSafetyCheckCreated = onDocumentCreated(
  { document: "users/{uid}/safetyChecks/{checkId}", retry: true },
  (event) => processRequest(deps(), event.params.uid, event.params.checkId),
);

/** Sends what is waiting to be retried. */
export const retryEscalations = onSchedule("every 5 minutes", async () => {
  await retryDue(deps());
});

/** An account was deleted: what only the backend can reach goes with it. */
export const onAccountDeleted = region("me-central2")
  .auth.user()
  .onDelete((user) => eraseBackendData(getFirestore(), user.uid));

export const createContactInvite = onCall((request) =>
  answering(() =>
    createInvite(
      getFirestore(),
      signedInUid(request),
      textField(request, "contactId"),
      new Date(),
    ),
  ),
);

export const acceptContactInvite = onCall((request) =>
  answering(() =>
    acceptInvite(
      getFirestore(),
      signedInUid(request),
      textField(request, "code"),
      new Date(),
    ),
  ),
);
