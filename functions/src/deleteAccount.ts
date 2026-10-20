import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { chunk, errorCode } from "./recipients.js";

/** Deleting needs a sign-in this recent (AppConfig.accountRecentLoginSeconds); the app reauthenticates first. */
export const RECENT_LOGIN_SECONDS = 300;
/** Tolerated clock skew when `auth_time` looks slightly in the future. */
const CLOCK_SKEW_SECONDS = 60;
/** Photo prefixes deleted in parallel. */
const PHOTO_DELETE_CONCURRENCY = 10;

/** True when the ID token's `auth_time` (seconds) is within the last `maxAgeSeconds`. */
export function isRecentLogin(authTime: unknown, nowMs: number, maxAgeSeconds: number = RECENT_LOGIN_SECONDS): boolean {
  if (typeof authTime !== "number" || !Number.isFinite(authTime)) return false;
  const ageSeconds = nowMs / 1000 - authTime;
  return ageSeconds >= -CLOCK_SKEW_SECONDS && ageSeconds <= maxAgeSeconds;
}

/** Firestore auto-IDs (and what storage.rules accepts): exactly 20 letters or digits. */
export function isPostId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9]{20}$/.test(value);
}

/**
 * Storage prefix for every photo of a post: `postImages/{id}.jpg` and `postImages/{id}_1..3.jpg`.
 * Null for a malformed ID, so a short or empty ID can never widen the prefix.
 */
export function photoPrefix(postId: unknown): string | null {
  return isPostId(postId) ? `postImages/${postId}` : null;
}

/** Docs keyed by the user's uid besides the profile: their appeal and their moderation record (strikes, bans). */
export function uidKeyedDocPaths(uid: string): string[] {
  return [`appeals/${uid}`, `moderation/${uid}`];
}

/**
 * Deletes the caller's account (App Store Guideline 5.1.1(v)). Data goes before the Auth user, so a run that
 * fails halfway can be retried by the same signed-in user; every step is idempotent. Order: each post's photos
 * then the post; the user's reports, appeal, moderation record, and every block they made or received (one bulk
 * writer, so deleting resets strikes); the profile (with alert filters and device registration); the Auth user.
 * Reports other people filed about the user's posts stay until their 90-day TTL. Logs carry counts only.
 */
export const deleteAccount = onCall({ region: "us-central1", enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in again to delete your account.");
  if (!isRecentLogin(request.auth?.token.auth_time, Date.now())) {
    throw new HttpsError("failed-precondition", "recent-login-required");
  }

  const db = getFirestore();
  const bucket = getStorage().bucket();

  const posts = await db.collection("posts").where("authorUid", "==", uid).select().get();
  const prefixes = posts.docs.map((doc) => photoPrefix(doc.id)).filter((prefix): prefix is string => prefix !== null);
  for (const batch of chunk(prefixes, PHOTO_DELETE_CONCURRENCY)) {
    await Promise.all(batch.map((prefix) => bucket.deleteFiles({ prefix })));
  }

  const [reports, blocksMade, blocksReceived] = await Promise.all([
    db.collection("reports").where("reporterUid", "==", uid).select().get(),
    db.collection("blocks").where("blockerUid", "==", uid).select().get(),
    db.collection("blocks").where("blockedUid", "==", uid).select().get(),
  ]);
  const writer = db.bulkWriter();
  for (const doc of [...posts.docs, ...reports.docs, ...blocksMade.docs, ...blocksReceived.docs]) {
    void writer.delete(doc.ref);
  }
  // Deleting a missing doc succeeds, so these are safe on a retry.
  for (const path of uidKeyedDocPaths(uid)) void writer.delete(db.doc(path));
  await writer.close();

  await db.collection("users").doc(uid).delete();

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    // A retry after the Auth user is already gone still succeeds.
    if (errorCode(error) !== "auth/user-not-found") {
      logger.error("Couldn't delete the Auth user", { code: errorCode(error) });
      throw new HttpsError("internal", "auth-delete-failed");
    }
  }

  logger.info("Account deleted", {
    posts: posts.size, photoPrefixes: prefixes.length, reports: reports.size,
    blocksMade: blocksMade.size, blocksReceived: blocksReceived.size,
  });
  return { deleted: true };
});
