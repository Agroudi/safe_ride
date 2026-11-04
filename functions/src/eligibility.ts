import { Timestamp } from "firebase-admin/firestore";

/** Why an escalation request ends without alerting anyone. */
export type Rejection =
  | "accountUnavailable"
  | "checkInvalid"
  | "notEscalationReady"
  | "deadlineNotPassed"
  | "incidentInvalid"
  | "journeyMissing"
  | "journeyNotActive"
  | "stale"
  | "duplicateJourney"
  | "rateLimited";

export type Data = FirebaseFirestore.DocumentData;

/** An earlier escalation of the same account, for the limits below. */
export interface RecentEscalation {
  journeyId: string;
  status: string;
  createdAt: Date;
}

export interface EligibilityInput {
  uid: string;
  checkId: string;
  now: Date;
  accountUsable: boolean;
  check: Data | undefined;
  incident: Data | undefined;
  journey: Data | undefined;
  recent: RecentEscalation[];
}

export const Limits = {
  /**
   * A request older than this tells a contact nothing they can act on, and
   * frightens them about something long over.
   */
  maxRequestAgeMs: 24 * 60 * 60 * 1000,

  /** Two phones recording one journey make two checks; one alert is enough. */
  journeyCooldownMs: 30 * 60 * 1000,

  /** Bounds what a forged request can do to the account's own contacts. */
  perAccountPerDay: 3,
} as const;

const movementTypes = ["suddenDeceleration", "prolongedStop"];
const askedConfidence = ["medium", "high"];

/**
 * Every check made before anyone is alerted. Everything the phone sent is
 * only a claim: the paths come from the trigger, and each referenced
 * document must agree with the others.
 */
export function rejectionOf(input: EligibilityInput): Rejection | null {
  const { uid, checkId, now, check, incident, journey } = input;
  if (!input.accountUsable) return "accountUnavailable";
  if (check === undefined || check.uid !== uid) return "checkInvalid";
  if (check.status !== "escalationReady") return "notEscalationReady";
  if (!(check.deadline instanceof Timestamp)) return "checkInvalid";
  const deadline = check.deadline.toDate();
  if (now.getTime() < deadline.getTime()) return "deadlineNotPassed";
  if (
    incident === undefined ||
    incident.journeyId !== check.journeyId ||
    incident.safetyCheckId !== checkId ||
    !movementTypes.includes(incident.type) ||
    !askedConfidence.includes(incident.confidence)
  ) {
    return "incidentInvalid";
  }
  if (journey === undefined) return "journeyMissing";
  // Closed by the user: they were there to close it, whatever the phone
  // queued while offline.
  if (journey.status !== "active") return "journeyNotActive";
  if (now.getTime() - deadline.getTime() > Limits.maxRequestAgeMs) {
    return "stale";
  }
  const alerted = input.recent.filter((r) => r.status !== "rejected");
  const cooling = now.getTime() - Limits.journeyCooldownMs;
  if (
    alerted.some(
      (r) =>
        r.journeyId === check.journeyId && r.createdAt.getTime() >= cooling,
    )
  ) {
    return "duplicateJourney";
  }
  if (alerted.length >= Limits.perAccountPerDay) return "rateLimited";
  return null;
}
