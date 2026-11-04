import { Message, Messaging } from "firebase-admin/messaging";

/** One install of a contact's SafeRide. */
export interface Device {
  installId: string;
  fid: string;
}

export interface Alert {
  /** The same for every attempt: a resend replaces, never stacks. */
  key: string;
  title: string;
  body: string;
}

/**
 * What a provider said. `accepted` means it took the request, and nothing
 * more: FCM reports neither delivery nor reading.
 */
export type SendResult =
  | { outcome: "accepted"; providerIds: string[]; staleDevices: string[] }
  | { outcome: "retry"; code: string }
  | { outcome: "failed"; code: string; staleDevices: string[] };

/** How an alert leaves SafeRide. SMS would be one more of these. */
export interface AlertChannel {
  readonly name: string;
  send(devices: Device[], alert: Alert): Promise<SendResult>;
}

/** The device no longer exists for FCM; sending again cannot help. */
const goneCodes = [
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
];

/** The route the app opens for a received alert (`AppRoutes.safetyAlerts`). */
const openRoute = "safety-alerts";

/** The Android channel the app creates (`LocalSafetyNotifications`). */
const androidChannel = "trusted_contact_alerts";

/** Firebase Cloud Messaging, addressed by Firebase Installation ID. */
export class FcmChannel implements AlertChannel {
  readonly name = "fcm";

  constructor(private readonly messaging: Pick<Messaging, "sendEach">) {}

  async send(devices: Device[], alert: Alert): Promise<SendResult> {
    const messages: Message[] = devices.map((d) => ({
      fid: d.fid,
      notification: { title: alert.title, body: alert.body },
      data: { route: openRoute },
      android: {
        priority: "high",
        collapseKey: alert.key,
        notification: { tag: alert.key, channelId: androidChannel },
      },
      apns: {
        headers: { "apns-priority": "10", "apns-collapse-id": alert.key },
      },
    }));
    let responses;
    try {
      responses = (await this.messaging.sendEach(messages)).responses;
    } catch (e) {
      return { outcome: "retry", code: errorCode(e) };
    }
    const providerIds: string[] = [];
    const staleDevices: string[] = [];
    let retryCode: string | null = null;
    let lastCode = "unknown";
    responses.forEach((r, i) => {
      if (r.success) {
        providerIds.push(r.messageId ?? "");
        return;
      }
      lastCode = errorCode(r.error);
      if (goneCodes.includes(lastCode)) {
        staleDevices.push(devices[i].installId);
      } else {
        retryCode = lastCode;
      }
    });
    if (providerIds.length > 0) {
      return { outcome: "accepted", providerIds, staleDevices };
    }
    if (retryCode !== null) return { outcome: "retry", code: retryCode };
    return { outcome: "failed", code: lastCode, staleDevices };
  }
}

function errorCode(e: unknown): string {
  const code = (e as { code?: unknown } | undefined)?.code;
  return typeof code === "string" ? code : "unknown";
}
