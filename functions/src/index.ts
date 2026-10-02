import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

initializeApp();
const db = getFirestore();

const ALERT_TITLE = "Free food on campus";
const MAX_BODY_LENGTH = 120;
/** FCM multicast limit per call. */
const BATCH_SIZE = 500;
const STALE_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/**
 * Sends one alert per new post to every opted-in user except the author.
 * The payload carries only the post title and `postId`: no names, emails or locations.
 * Delivery is at-least-once, so `notificationSends/{postId}` is created first and a repeat run stops there.
 */
export const onPostCreated = onDocumentCreated("posts/{postId}", async (event) => {
  const post = event.data?.data();
  if (!post) return;
  const postId = event.params.postId;

  if (post.status !== "active") return;

  try {
    await db.collection("notificationSends").doc(postId).create({ createdAt: FieldValue.serverTimestamp() });
  } catch {
    logger.info("Alert already sent for post", { postId });
    return;
  }

  const snapshot = await db.collection("users").where("notificationsEnabled", "==", true).get();
  const tokens = new Set<string>();
  for (const doc of snapshot.docs) {
    if (doc.id === post.authorUid) continue;
    const token = doc.get("fcmToken");
    if (typeof token === "string" && token.length > 0) tokens.add(token);
  }

  const body = String(post.title ?? "").slice(0, MAX_BODY_LENGTH);
  const all = [...tokens];
  let sent = 0;
  let failed = 0;
  const stale: string[] = [];

  for (let start = 0; start < all.length; start += BATCH_SIZE) {
    const batch = all.slice(start, start + BATCH_SIZE);
    const result = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: { title: ALERT_TITLE, body },
      data: { postId },
      apns: { payload: { aps: { sound: "default" } } },
    });
    sent += result.successCount;
    failed += result.failureCount;
    result.responses.forEach((response, index) => {
      if (!response.success && STALE_TOKEN_CODES.has(response.error?.code ?? "")) stale.push(batch[index]);
    });
  }

  // Drop tokens FCM says are dead so they are not retried for every future post.
  for (const token of stale) {
    const owners = await db.collection("users").where("fcmToken", "==", token).get();
    await Promise.all(owners.docs.map((doc) => doc.ref.update({ fcmToken: FieldValue.delete() })));
  }

  logger.info("Post alert sent", { postId, recipients: all.length, sent, failed, staleRemoved: stale.length });
});
