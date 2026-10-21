import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import {
  ALERT_TITLE,
  MAX_IDS_PER_SEND,
  STALE_ID_ERROR_CODES,
  type Subscriber,
  alertBody,
  chunk,
  errorCode,
  isAlreadyExists,
  recipientIds,
} from "./recipients.js";
import { alertSubtitle } from "./filters.js";
import { passesPostChecks } from "./post-checks.js";

export { onAdminActionCreated } from "./adminActions.js";
export { aiHealthCheck } from "./aiHealth.js";
export { onAppealWritten } from "./appeals.js";
export { onProfileEmailSet } from "./banHolds.js";
export { onBlockCreated } from "./blocks.js";
export { deleteAccount } from "./deleteAccount.js";
export { onReportCreated } from "./moderation.js";

initializeApp();

/** Marker docs (`postAlerts/{postId}`) live this long; a TTL policy on `deleteAt` removes them. */
const ALERT_MARKER_RETENTION_MS = 24 * 60 * 60 * 1000;

/**
 * New post -> the content filter and photo screening (`post-checks.ts`; a failing post is removed and alerts no
 * one), then one alert per opted-in device whose owner's filters match, except the author's and people who blocked
 * the author. Payload: title, a subtitle of post facts (the same for everyone), the post title, and `postId` only.
 * Runs in us-central1 to match the Firestore location (nam5). Logs counts only, never IDs or content.
 */
export const onPostCreated = onDocumentCreated(
  // Photo screening downloads up to 4 photos and waits for one AI call.
  { document: "posts/{postId}", region: "us-central1", retry: false, memory: "512MiB", timeoutSeconds: 60 },
  async (event) => {
    const post = event.data?.data();
    const postId = event.params.postId;
    if (!post) return;
    if (post.status !== "active") return;
    const expiresAt = post.expiresAt instanceof Timestamp ? post.expiresAt.toMillis() : 0;
    if (expiresAt <= Date.now()) return;
    const body = alertBody(post.title);
    if (!body) return;
    const authorUid = typeof post.authorUid === "string" ? post.authorUid : "";

    const db = getFirestore();
    // Events can be delivered more than once: only the first delivery creates the marker and sends.
    try {
      await db.collection("postAlerts").doc(postId).create({
        sentAt: FieldValue.serverTimestamp(),
        deleteAt: Timestamp.fromMillis(Date.now() + ALERT_MARKER_RETENTION_MS),
      });
    } catch (error) {
      if (isAlreadyExists(error)) {
        logger.info("Alert already sent for this post", { postId });
        return;
      }
      // Anything else (e.g. PERMISSION_DENIED = 7 when the runtime service account lacks Firestore access)
      // is a real failure: log the code and fail the run so it shows up as an error.
      logger.error("Couldn't create the alert marker", { postId, code: errorCode(error) });
      throw error;
    }

    // Checked after the marker so a duplicate delivery never screens twice; before alerts so a flagged post never
    // alerts anyone.
    if (!(await passesPostChecks(postId, post))) return;

    const [subscribersSnapshot, authorSnapshot, blockersSnapshot] = await Promise.all([
      db.collection("users")
        .where("notificationsEnabled", "==", true)
        .select("notificationsEnabled", "fcmInstallationId", "quietHoursEnabled", "alertFilters")
        .get(),
      authorUid ? db.collection("users").doc(authorUid).get() : Promise.resolve(null),
      // People who blocked the author never get alerts for their posts.
      authorUid ? db.collection("blocks").where("blockedUid", "==", authorUid).select("blockerUid").get()
        : Promise.resolve(null),
    ]);
    const subscribers: Subscriber[] = subscribersSnapshot.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));
    const blockers = new Set((blockersSnapshot?.docs ?? [])
      .map((doc) => doc.get("blockerUid"))
      .filter((uid): uid is string => typeof uid === "string"));
    const { ids, filteredOut } = recipientIds(subscribers, post, authorUid,
      authorSnapshot?.get("fcmInstallationId"), new Date(), blockers);
    if (ids.length === 0) {
      logger.info("No alert recipients", { postId, subscribers: subscribers.length, filteredOut, blockers: blockers.size });
      return;
    }
    const subtitle = alertSubtitle(post);

    let sent = 0;
    const staleIds = new Set<string>();
    /** FCM error code -> count, so failures are diagnosable without logging IDs. */
    const errorCodes: Record<string, number> = {};
    /** First FCM message per code (truncated); FCM messages describe the failure, not the recipient. */
    const errorMessages: Record<string, string> = {};
    for (const batch of chunk(ids, MAX_IDS_PER_SEND)) {
      const response = await getMessaging().sendEachForMulticast({
        fids: batch,
        notification: { title: ALERT_TITLE, body },
        data: { postId },
        // The full APNs alert, so the subtitle never depends on how FCM merges it with `notification`.
        apns: {
          payload: {
            aps: {
              alert: { title: ALERT_TITLE, body, ...(subtitle ? { subtitle } : {}) },
              sound: "default",
            },
          },
        },
      });
      sent += response.successCount;
      response.responses.forEach((result, index) => {
        const code = result.error?.code;
        if (!code) return;
        errorCodes[code] = (errorCodes[code] ?? 0) + 1;
        errorMessages[code] ??= (result.error?.message ?? "").slice(0, 300);
        if (STALE_ID_ERROR_CODES.has(code)) staleIds.add(batch[index]);
      });
    }

    // Drop IDs that will never work again so the next alert doesn't retry them.
    const staleOwners = subscribers.filter((s) => typeof s.fcmInstallationId === "string" && staleIds.has(s.fcmInstallationId));
    await Promise.all(staleOwners.map((s) =>
      db.collection("users").doc(s.uid).update({ fcmInstallationId: FieldValue.delete() })));

    logger.info("Free food alert sent", {
      postId,
      recipients: ids.length,
      filteredOut,
      sent,
      failed: ids.length - sent,
      staleRemoved: staleOwners.length,
      errorCodes,
      errorMessages,
    });
  },
);
