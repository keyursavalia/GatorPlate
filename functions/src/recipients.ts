/**
 * Who gets a free food alert. Pure functions, so they can be tested without Firebase.
 * Field names match the app's `FirebaseNotificationService` (users/{uid}).
 */

/** Campus time; quiet hours mirror AppConfig.quietHoursStartHour / quietHoursEndHour in the app. */
export const CAMPUS_TIME_ZONE = "America/Los_Angeles";
export const QUIET_HOURS_START = 23;
export const QUIET_HOURS_END = 7;

export const ALERT_TITLE = "Free food on campus";
export const MAX_BODY_LENGTH = 120;
/** FCM limit for one multicast. */
export const MAX_IDS_PER_SEND = 500;

export interface Subscriber {
  uid: string;
  notificationsEnabled?: unknown;
  fcmInstallationId?: unknown;
  quietHoursEnabled?: unknown;
}

export function isInstallationId(value: unknown): value is string {
  return typeof value === "string" && value.length >= 10 && value.length <= 256;
}

/** Hour 0-23 at `date` in campus time. */
export function campusHour(date: Date, timeZone: string = CAMPUS_TIME_ZONE): number {
  const hour = new Intl.DateTimeFormat("en-US", { hour: "numeric", hourCycle: "h23", timeZone }).format(date);
  return Number.parseInt(hour, 10);
}

/** 11 PM up to (not including) 7 AM campus time. */
export function isQuietHours(date: Date, timeZone: string = CAMPUS_TIME_ZONE): boolean {
  const hour = campusHour(date, timeZone);
  return hour >= QUIET_HOURS_START || hour < QUIET_HOURS_END;
}

/**
 * Installation IDs to alert: opted in, valid ID, not the author (nor any device the author uses),
 * not muted by quiet hours, each device once.
 */
export function recipientIds(
  subscribers: Subscriber[],
  authorUid: string,
  authorInstallationId: unknown,
  now: Date,
): string[] {
  const authorIds = new Set<string>();
  if (isInstallationId(authorInstallationId)) authorIds.add(authorInstallationId);
  for (const subscriber of subscribers) {
    if (subscriber.uid === authorUid && isInstallationId(subscriber.fcmInstallationId)) {
      authorIds.add(subscriber.fcmInstallationId);
    }
  }

  const quiet = isQuietHours(now);
  const ids = new Set<string>();
  for (const subscriber of subscribers) {
    if (subscriber.uid === authorUid) continue;
    if (subscriber.notificationsEnabled !== true) continue;
    if (!isInstallationId(subscriber.fcmInstallationId)) continue;
    if (authorIds.has(subscriber.fcmInstallationId)) continue;
    if (quiet && subscriber.quietHoursEnabled === true) continue;
    ids.add(subscriber.fcmInstallationId);
  }
  return [...ids];
}

/** The post title as the alert body: trimmed, single line, at most MAX_BODY_LENGTH characters. */
export function alertBody(title: unknown): string | null {
  if (typeof title !== "string") return null;
  const clean = title.replace(/\s+/g, " ").trim();
  if (clean.length === 0) return null;
  const characters = [...clean];
  if (characters.length <= MAX_BODY_LENGTH) return clean;
  return characters.slice(0, MAX_BODY_LENGTH - 1).join("").trimEnd() + "…";
}

export function chunk<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

/** Errors meaning the ID will never work again, so it's removed from the profile. */
export const STALE_ID_ERROR_CODES = new Set([
  "messaging/installation-id-not-registered",
  "messaging/registration-token-not-registered",
  "messaging/invalid-recipient",
]);
