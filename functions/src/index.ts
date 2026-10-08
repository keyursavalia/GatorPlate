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
  recipientIds,
} from "./recipients.js";

initializeApp();

/** Marker docs (`postAlerts/{postId}`) live this long; a TTL policy on `deleteAt` removes them. */
const ALERT_MARKER_RETENTION_MS = 24 * 60 * 60 * 1000;

/**
 * New post -> one alert per opted-in device, except the author's. Payload: title, post title, `postId` only.
 * Runs in us-central1 to match the Firestore location (nam5). Logs counts only, never IDs or content.
 */
export const onPostCreated = onDocumentCreated(
  { document: "posts/{postId}", region: "us-central1", retry: false },
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
    } catch {
      logger.info("Alert already sent for this post", { postId });
      return;
    }

    const [subscribersSnapshot, authorSnapshot] = await Promise.all([
      db.collection("users")
        .where("notificationsEnabled", "==", true)
        .select("notificationsEnabled", "fcmInstallationId", "quietHoursEnabled")
        .get(),
      authorUid ? db.collection("users").doc(authorUid).get() : Promise.resolve(null),
    ]);
    const subscribers: Subscriber[] = subscribersSnapshot.docs.map((doc) => ({ uid: doc.id, ...doc.data() }));
    const ids = recipientIds(subscribers, authorUid, authorSnapshot?.get("fcmInstallationId"), new Date());
    if (ids.length === 0) {
      logger.info("No alert recipients", { postId, subscribers: subscribers.length });
      return;
    }

    let sent = 0;
    const staleIds = new Set<string>();
    for (const batch of chunk(ids, MAX_IDS_PER_SEND)) {
      const response = await getMessaging().sendEachForMulticast({
        fids: batch,
        notification: { title: ALERT_TITLE, body },
        data: { postId },
        apns: { payload: { aps: { sound: "default" } } },
      });
      sent += response.successCount;
      response.responses.forEach((result, index) => {
        const code = result.error?.code;
        if (code && STALE_ID_ERROR_CODES.has(code)) staleIds.add(batch[index]);
      });
    }

    // Drop IDs that will never work again so the next alert doesn't retry them.
    const staleOwners = subscribers.filter((s) => typeof s.fcmInstallationId === "string" && staleIds.has(s.fcmInstallationId));
    await Promise.all(staleOwners.map((s) =>
      db.collection("users").doc(s.uid).update({ fcmInstallationId: FieldValue.delete() })));

    logger.info("Free food alert sent", {
      postId,
      recipients: ids.length,
      sent,
      failed: ids.length - sent,
      staleRemoved: staleOwners.length,
    });
  },
);
