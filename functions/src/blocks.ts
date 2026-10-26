/**
 * Block notifications for the developer (App Review 1.2): every new `blocks/{blockerUid}_{blockedUid}` doc adds one
 * to `moderation/{blockedUid}.blockedByCount`; once a poster reaches `block_admin_alert_threshold`, the admins get
 * one push for review. Logs counts only, never uids or names.
 */
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { pushToAdmins } from "./moderation-actions.js";
import { serverConfig } from "./runtimeConfig.js";

export const onBlockCreated = onDocumentCreated(
  { document: "blocks/{blockId}", region: "us-central1", retry: false },
  async (event) => {
    const blockedUid = event.data?.get("blockedUid");
    if (typeof blockedUid !== "string" || blockedUid.length === 0 || blockedUid.length > 128) {
      logger.warn("Malformed block ignored");
      return;
    }
    const config = await serverConfig();
    const db = getFirestore();
    const moderationRef = db.collection("moderation").doc(blockedUid);
    const { count, alert } = await db.runTransaction(async (transaction) => {
      const moderation = await transaction.get(moderationRef);
      const previous = moderation.get("blockedByCount");
      const next = (typeof previous === "number" && Number.isFinite(previous) ? previous : 0) + 1;
      const alreadyAlerted = moderation.get("blockAlertSentAt") !== undefined;
      const shouldAlert = next >= config.blockAdminAlertThreshold && !alreadyAlerted;
      transaction.set(moderationRef, {
        blockedByCount: next,
        updatedAt: FieldValue.serverTimestamp(),
        ...(shouldAlert ? { blockAlertSentAt: FieldValue.serverTimestamp() } : {}),
      }, { merge: true });
      return { count: next, alert: shouldAlert };
    });
    logger.info("Block counted", { blockedBy: count, adminAlert: alert });
    if (alert) {
      await pushToAdmins(config, {
        title: `A poster was blocked by ${count} ${count === 1 ? "person" : "people"}`,
        body: "Review their posts and reports in the Firebase console.",
        kind: "adminReview",
      });
    }
  },
);
