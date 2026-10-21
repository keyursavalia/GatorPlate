/**
 * Pure validation for `adminActions/{id}` docs, which the owner creates in the Firebase console to run a
 * moderation action (tested with `node --test`). Field names and examples are in docs/06-OPERATIONS.md.
 */
import { CAMPUS_TIME_ZONE } from "./filters.js";

export const ADMIN_ACTIONS = ["removePost", "dismissReports", "resolveAppeal", "liftBan", "clearStrikes"] as const;
export type AdminActionName = (typeof ADMIN_ACTIONS)[number];
export const APPEAL_DECISIONS = ["upheld", "denied"] as const;
export type AppealDecision = (typeof APPEAL_DECISIONS)[number];
/** The note shown to the user with an appeal decision. */
export const NOTE_MAX_LENGTH = 200;

export type AdminAction =
  | { action: "removePost"; postId: string; strike: boolean; note: string | null }
  | { action: "dismissReports"; postId: string }
  | { action: "resolveAppeal"; uid: string; decision: AppealDecision; clearStrikes: boolean; note: string | null }
  | { action: "liftBan"; uid: string; clearStrikes: boolean }
  | { action: "clearStrikes"; uid: string };

export type ParsedAdminAction = { ok: true; value: AdminAction } | { ok: false; error: string };

/** A Firebase uid: 1-128 characters, no slashes (it becomes a document ID). */
export function isUid(value: unknown): value is string {
  return typeof value === "string" && value.length >= 1 && value.length <= 128 && !value.includes("/") &&
    value.trim() === value;
}

function isPostIdValue(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9]{1,40}$/.test(value);
}

function optionalBool(data: Record<string, unknown>, key: string, fallback: boolean): boolean | string {
  const value = data[key];
  if (value === undefined) return fallback;
  return typeof value === "boolean" ? value : `${key} must be true or false`;
}

function optionalNote(data: Record<string, unknown>): string | null | { error: string } {
  const value = data.note;
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") return { error: "note must be text" };
  const note = value.trim();
  if (note.length > NOTE_MAX_LENGTH) return { error: `note must be at most ${NOTE_MAX_LENGTH} characters` };
  return note.length > 0 ? note : null;
}

/** Validates an admin action doc. Errors are short and safe to store in `result`. */
export function parseAdminAction(raw: unknown): ParsedAdminAction {
  if (typeof raw !== "object" || raw === null) return { ok: false, error: "Not an object" };
  const data = raw as Record<string, unknown>;
  const action = data.action;
  if (typeof action !== "string" || !(ADMIN_ACTIONS as readonly string[]).includes(action)) {
    return { ok: false, error: `action must be one of ${ADMIN_ACTIONS.join(", ")}` };
  }
  const fail = (error: string): ParsedAdminAction => ({ ok: false, error });

  switch (action as AdminActionName) {
    case "removePost": {
      if (!isPostIdValue(data.postId)) return fail("postId is missing or invalid");
      const strike = optionalBool(data, "strike", true);
      if (typeof strike === "string") return fail(strike);
      const note = optionalNote(data);
      if (note !== null && typeof note === "object") return fail(note.error);
      return { ok: true, value: { action: "removePost", postId: data.postId, strike, note } };
    }
    case "dismissReports": {
      if (!isPostIdValue(data.postId)) return fail("postId is missing or invalid");
      return { ok: true, value: { action: "dismissReports", postId: data.postId } };
    }
    case "resolveAppeal": {
      if (!isUid(data.uid)) return fail("uid is missing or invalid");
      const decision = data.decision;
      if (typeof decision !== "string" || !(APPEAL_DECISIONS as readonly string[]).includes(decision)) {
        return fail("decision must be upheld or denied");
      }
      const clearStrikes = optionalBool(data, "clearStrikes", false);
      if (typeof clearStrikes === "string") return fail(clearStrikes);
      const note = optionalNote(data);
      if (note !== null && typeof note === "object") return fail(note.error);
      return {
        ok: true,
        value: { action: "resolveAppeal", uid: data.uid, decision: decision as AppealDecision, clearStrikes, note },
      };
    }
    case "liftBan": {
      if (!isUid(data.uid)) return fail("uid is missing or invalid");
      const clearStrikes = optionalBool(data, "clearStrikes", false);
      if (typeof clearStrikes === "string") return fail(clearStrikes);
      return { ok: true, value: { action: "liftBan", uid: data.uid, clearStrikes } };
    }
    case "clearStrikes": {
      if (!isUid(data.uid)) return fail("uid is missing or invalid");
      return { ok: true, value: { action: "clearStrikes", uid: data.uid } };
    }
  }
}

/** The push a user gets for an appeal decision. `bannedUntilMs` is the running ban's end (denied only). */
export function appealDecisionPush(decision: AppealDecision, bannedUntilMs: number | null,
  timeZone: string = CAMPUS_TIME_ZONE): { title: string; body: string } {
  if (decision === "upheld") {
    return { title: "Appeal accepted", body: "Your appeal was accepted. You can post again." };
  }
  if (bannedUntilMs === null) {
    return { title: "Appeal reviewed", body: "Your appeal was reviewed. Posting stays paused for now." };
  }
  const date = new Intl.DateTimeFormat("en-US", {
    month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone,
  }).format(new Date(bannedUntilMs));
  return { title: "Appeal reviewed", body: `Your appeal was reviewed. Posting stays paused until ${date}.` };
}

/**
 * Whether an appeal write came from the user (a new or changed message without a decision), which pushes the
 * admins. The function's own decision writes have `resolution` and are skipped.
 */
export function isUserAppealWrite(before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined): boolean {
  if (!after || typeof after.message !== "string") return false;
  if (after.resolution !== undefined) return false;
  return before?.message !== after.message || before?.bannedUntil !== after.bannedUntil;
}
