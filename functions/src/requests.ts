import { Auth } from "firebase-admin/auth";
import {
  CallableRequest,
  FunctionsErrorCode,
  HttpsError,
} from "firebase-functions/v2/https";
import { InviteError, InviteProblem } from "./invites";

/** The caller's uid from their verified token — never from the request body. */
export function signedInUid(request: Pick<CallableRequest, "auth">): string {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError("unauthenticated", "signIn");
  return uid;
}

export function textField(
  request: Pick<CallableRequest, "data">,
  key: string,
): string {
  const value = (request.data as Record<string, unknown> | null)?.[key];
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > 128 ||
    value.includes("/")
  ) {
    throw new HttpsError("invalid-argument", key);
  }
  return value;
}

/** False for a deleted or disabled account. */
export async function accountUsable(
  auth: Pick<Auth, "getUser">,
  uid: string,
): Promise<boolean> {
  try {
    return !(await auth.getUser(uid)).disabled;
  } catch (e) {
    if ((e as { code?: string }).code === "auth/user-not-found") return false;
    throw e; // A passing failure: the trigger's retry tries again.
  }
}

/**
 * The app tells these apart by code. `not-found` is deliberately unused: a
 * function that is not deployed answers with it, and that is not a bad code.
 */
const inviteErrors: Record<InviteProblem, FunctionsErrorCode> = {
  contactNotFound: "failed-precondition",
  invalidCode: "invalid-argument",
  expired: "failed-precondition",
  used: "failed-precondition",
  ownInvite: "permission-denied",
};

/** Runs [work], turning an [InviteError] into what the caller receives. */
export async function answering<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (e) {
    if (e instanceof InviteError) {
      throw new HttpsError(inviteErrors[e.problem], e.problem);
    }
    throw e;
  }
}
