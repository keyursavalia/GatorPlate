/**
 * Shared moderation side effects: removing a post (reports, photo screening, the text filter, admin actions) and
 * pushing the poster or the admins. Logs categories and counts only, never IDs, names or text.
 */
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import type { ServerConfig } from "./config-logic.js";
import { photoPrefix } from "./deleteAccount.js";
import {
  type RemovalCategory,
  type StrikeCategory,
  banEndMs,
  isStrikeCategory,
  parseRemovals,
  removalsInWindow,
} from "./moderation-logic.js";
import { errorCode, isAlreadyExists } from "./recipients.js";

/** Removal markers live this long; a TTL policy on `deleteAt` removes them. */
const REMOVAL_MARKER_RETENTION_MS = 24 * 60 * 60 * 1000;

/** Push `data.kind` values the app understands (`FirebaseNotificationService+Taps`). */
export type PushKind = "postRemoved" | "appealResolved" | "adminReview";

export interface PushMessage {
  title: string;
  body: string;
  kind: PushKind;
}

export interface RemovalOptions {
  category: RemovalCategory;
  /** Records a strike (and maybe a ban). True for report and admin removals; false for screened / filtered. */
  strike: boolean;
  /** Tells the poster, when set. */
  push?: PushMessage;
}

/**
 * Removes a post once (the marker first, so a second trigger stops), deletes its photos and the doc, then records
 * the strike and starts a ban per the configured rules. Returns false when the post was already removed.
 */
export async function removePost(postId: string, post: Record<string, unknown>, options: RemovalOptions,
  config: ServerConfig): Promise<boolean> {
  const { category } = options;
  const db = getFirestore();
  try {
    await db.collection("postRemovals").doc(postId).create({
      category,
      removedAt: FieldValue.serverTimestamp(),
      deleteAt: Timestamp.fromMillis(Date.now() + REMOVAL_MARKER_RETENTION_MS),
    });
  } catch (error) {
    if (isAlreadyExists(error)) {
      logger.info("Post already removed", { category });
      return false;
    }
    logger.error("Couldn't create the removal marker", { code: errorCode(error) });
    throw error;
  }

  const prefix = photoPrefix(postId);
  if (prefix) {
    try {
      await getStorage().bucket().deleteFiles({ prefix });
    } catch (error) {
      logger.warn("Couldn't delete the removed post's photos", { code: errorCode(error) });
    }
  }
  await db.collection("posts").doc(postId).delete();

  const authorUid = typeof post.authorUid === "string" ? post.authorUid : "";
  if (!authorUid) return true;

  if (options.strike && isStrikeCategory(category)) {
    const { removalCount, banned } = await recordStrike(authorUid, postId, category, config);
    logger.info("Post removed", { category, strike: true, removalsInWindow: removalCount, banned });
  } else {
    logger.info("Post removed", { category, strike: false });
  }

  await recordRemovalNotice(authorUid, category);
  if (options.push) await pushToUser(authorUid, options.push);
  return true;
}

/**
 * `users/{uid}.lastRemoval`: the app shows it once as a banner, so the poster learns about the removal even without
 * push. The category only, never the post or who reported it. A missing profile (deleted account) is fine.
 */
async function recordRemovalNotice(authorUid: string, category: RemovalCategory) {
  try {
    await getFirestore().collection("users").doc(authorUid).update({
      lastRemoval: { category, removedAt: FieldValue.serverTimestamp() },
    });
  } catch (error) {
    logger.info("No profile for the removal notice", { code: errorCode(error) });
  }
}

/** Appends the strike, prunes the window, and bans on the configured count. Never shortens a running ban. */
async function recordStrike(authorUid: string, postId: string, category: StrikeCategory,
  config: ServerConfig): Promise<{ removalCount: number; banned: boolean }> {
  const db = getFirestore();
  const now = Date.now();
  const moderationRef = db.collection("moderation").doc(authorUid);
  const userRef = db.collection("users").doc(authorUid);
  return db.runTransaction(async (transaction) => {
    const [moderation, user] = await Promise.all([transaction.get(moderationRef), transaction.get(userRef)]);
    const removals = removalsInWindow(
      [...parseRemovals(moderation.get("removals")), { postId, category, atMs: now }],
      now, config.strikeWindowDays);
    const banEnd = banEndMs(removals.length, now, config.banAfterRemovals, config.banDays);
    const existingBan = user.get("postingBannedUntil");
    const existingBanMs = existingBan instanceof Timestamp ? existingBan.toMillis() : 0;
    const bannedUntil = banEnd !== null && banEnd > existingBanMs ? banEnd : null;
    transaction.set(moderationRef, {
      removals,
      updatedAt: FieldValue.serverTimestamp(),
      ...(bannedUntil !== null ? { bannedUntil: Timestamp.fromMillis(bannedUntil), bannedAt: FieldValue.serverTimestamp() } : {}),
    }, { merge: true });
    if (bannedUntil !== null && user.exists) {
      transaction.update(userRef, { postingBannedUntil: Timestamp.fromMillis(bannedUntil) });
    }
    return { removalCount: removals.length, banned: bannedUntil !== null };
  });
}

/** Installation IDs of these users that have one registered. */
async function installationIds(uids: readonly string[]): Promise<string[]> {
  if (uids.length === 0) return [];
  const db = getFirestore();
  const users = await db.getAll(...uids.map((uid) => db.collection("users").doc(uid)));
  const ids = users
    .map((user) => user.get("fcmInstallationId"))
    .filter((fid): fid is string => typeof fid === "string" && fid.length > 0);
  return [...new Set(ids)];
}

async function send(ids: string[], message: PushMessage, data: Record<string, string>): Promise<number> {
  if (ids.length === 0) return 0;
  const response = await getMessaging().sendEachForMulticast({
    fids: ids,
    notification: { title: message.title, body: message.body },
    data: { ...data, kind: message.kind },
    apns: { payload: { aps: { alert: { title: message.title, body: message.body }, sound: "default" } } },
  });
  return response.successCount;
}

/** Pushes one user's registered device. Logs counts only; never throws. */
export async function pushToUser(uid: string, message: PushMessage, data: Record<string, string> = {}): Promise<void> {
  try {
    const ids = await installationIds([uid]);
    if (ids.length === 0) {
      logger.info("User has no device for the notice", { kind: message.kind });
      return;
    }
    const sent = await send(ids, message, data);
    logger.info("User notice sent", { kind: message.kind, sent });
  } catch (error) {
    logger.warn("Couldn't send the user notice", { kind: message.kind, code: errorCode(error) });
  }
}

/** Pushes every admin in `admin_uids` with a device. Logs counts only; never throws. */
export async function pushToAdmins(config: ServerConfig, message: PushMessage,
  data: Record<string, string> = {}): Promise<void> {
  if (config.adminUids.length === 0) {
    logger.warn("No admin_uids configured; admin notice skipped", { kind: message.kind });
    return;
  }
  try {
    const ids = await installationIds(config.adminUids);
    const sent = await send(ids, message, data);
    logger.info("Admin notice sent", { kind: message.kind, admins: config.adminUids.length, devices: ids.length, sent });
  } catch (error) {
    logger.warn("Couldn't send the admin notice", { kind: message.kind, code: errorCode(error) });
  }
}
