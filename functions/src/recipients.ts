/**
 * Who gets a free food alert. Pure functions, so they can be tested without Firebase.
 * Field names match the app's `FirebaseNotificationService` (users/{uid}).
 */
import { CAMPUS_TIME_ZONE, type FilterablePost, matchesFilters } from "./filters.js";

export { CAMPUS_TIME_ZONE };
/** Quiet hours in campus time; the app's Settings label ("Mute notifications 11 PM – 7 AM") states the same. */
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
  /** The student's own "What to alert me about" choices; malformed or missing means all free food. */
  alertFilters?: unknown;
}

export interface Recipients {
  /** Installation IDs to alert, each device once. */
  ids: string[];
  /** Opted-in devices skipped only because the post didn't match their filters (a count, for logs). */
  filteredOut: number;
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
 * Installation IDs to alert: opted in, valid ID, not the author (nor any device the author uses), not someone who
 * blocked the author (`excludedUids`), not muted by quiet hours, then matching the student's filters, each device
 * once.
 */
export function recipientIds(
  subscribers: Subscriber[],
  post: FilterablePost,
  authorUid: string,
  authorInstallationId: unknown,
  now: Date,
  excludedUids: ReadonlySet<string> = new Set(),
): Recipients {
  const authorIds = new Set<string>();
  if (isInstallationId(authorInstallationId)) authorIds.add(authorInstallationId);
  for (const subscriber of subscribers) {
    if (subscriber.uid === authorUid && isInstallationId(subscriber.fcmInstallationId)) {
      authorIds.add(subscriber.fcmInstallationId);
    }
  }

  const quiet = isQuietHours(now);
  const ids = new Set<string>();
  let filteredOut = 0;
  for (const subscriber of subscribers) {
    if (subscriber.uid === authorUid) continue;
    if (excludedUids.has(subscriber.uid)) continue;
    if (subscriber.notificationsEnabled !== true) continue;
    if (!isInstallationId(subscriber.fcmInstallationId)) continue;
    if (authorIds.has(subscriber.fcmInstallationId)) continue;
    if (quiet && subscriber.quietHoursEnabled === true) continue;
    if (!matchesFilters(post, subscriber.alertFilters)) {
      filteredOut += 1;
      continue;
    }
    ids.add(subscriber.fcmInstallationId);
  }
  return { ids: [...ids], filteredOut };
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

/** gRPC status codes the Admin SDK puts on Firestore errors. */
const GRPC_ALREADY_EXISTS = 6;

/** True only when a `create()` failed because the document exists (a repeated event delivery). */
export function isAlreadyExists(error: unknown): boolean {
  return errorCode(error) === GRPC_ALREADY_EXISTS;
}

/** The error's `code` (number for Firestore, string like "messaging/..." for FCM), for logs. */
export function errorCode(error: unknown): number | string | undefined {
  if (typeof error !== "object" || error === null || !("code" in error)) return undefined;
  const code = (error as { code: unknown }).code;
  return typeof code === "number" || typeof code === "string" ? code : undefined;
}
