/**
 * A paused poster sent (or changed) an appeal: push the admins so a person reviews it. Decisions written by the
 * `resolveAppeal` admin action carry `resolution` and are skipped. Logs nothing about the appeal's content.
 */
import { Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { isUserAppealWrite } from "./admin-actions-logic.js";
import { pushToAdmins } from "./moderation-actions.js";
import { serverConfig } from "./runtimeConfig.js";

/** Timestamps compared by value, not by object. */
function comparable(data: Record<string, unknown> | undefined): Record<string, unknown> | undefined {
  if (!data) return undefined;
  const bannedUntil = data.bannedUntil instanceof Timestamp ? data.bannedUntil.toMillis() : data.bannedUntil;
  return { ...data, bannedUntil };
}

export const onAppealWritten = onDocumentWritten(
  { document: "appeals/{uid}", region: "us-central1", retry: false },
  async (event) => {
    const before = comparable(event.data?.before.data());
    const after = comparable(event.data?.after.data());
    if (!isUserAppealWrite(before, after)) return;
    logger.info("New appeal");
    await pushToAdmins(await serverConfig(), {
      title: "New appeal to review",
      body: "A paused poster sent an appeal. Review it in the Firebase console.",
      kind: "adminReview",
    });
  },
);
