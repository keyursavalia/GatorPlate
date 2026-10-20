import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { type ServerConfig, modelChain } from "./config-logic.js";
import { isPostId } from "./deleteAccount.js";
import { generateWithFallback } from "./genai.js";
import { pushToAdmins, removePost } from "./moderation-actions.js";
import {
  type UnsafeVerdict,
  CATEGORY_LABELS,
  UNSAFE_PUSH_BODY,
  UNSAFE_PUSH_TITLE,
  UNSAFE_VERDICT_SCHEMA,
  cleanReason,
  countsTowardThreshold,
  isCredibleUnsafe,
  isReportCategory,
  parseUnsafeVerdict,
  postFacts,
  reachesRemovalThreshold,
  reportDeleteAtMs,
  reportPostSnapshot,
  unsafeCheckPrompt,
} from "./moderation-logic.js";
import { errorCode } from "./recipients.js";
import { serverConfig } from "./runtimeConfig.js";

/** Storage path of one photo slot: `{id}.jpg` for the cover slot 0, `{id}_N.jpg` otherwise. */
function photoPath(postId: string, slot: number): string {
  return slot === 0 ? `postImages/${postId}.jpg` : `postImages/${postId}_${slot}.jpg`;
}

/**
 * New report -> maybe remove the post. Unsafe: the AI checks the reporter's reason against the post; credible
 * removes it and tells the poster. Otherwise (and for spam/misleading and trading) the report counts toward the
 * pooled threshold of distinct reporters (`report_removal_threshold`, default 3), which removes the post silently.
 * Each removal is a strike; enough strikes in the window pause posting (`ban_after_removals`, `ban_days`).
 * Offensive reports also push the admins for human review within 24 hours. Every report gets a `postSnapshot` for
 * review and a `deleteAt` 90 days out (TTL). Thresholds and the model chain come from the server Remote Config
 * template. Logs counts and verdicts only.
 */
export const onReportCreated = onDocumentCreated(
  { document: "reports/{reportId}", region: "us-central1", retry: false, memory: "512MiB", timeoutSeconds: 60 },
  async (event) => {
    const report = event.data?.data();
    if (!report || !event.data) return;
    const category = report.category;
    const postId = report.postId;
    if (!isReportCategory(category) || !isPostId(postId)) {
      logger.warn("Malformed report ignored");
      return;
    }

    const createdAtMs = report.createdAt instanceof Timestamp ? report.createdAt.toMillis() : Date.now();
    const deleteAt = Timestamp.fromMillis(reportDeleteAtMs(createdAtMs));
    const db = getFirestore();
    const postDoc = await db.collection("posts").doc(postId).get();
    const post = postDoc.data();
    if (!post) {
      await event.data.ref.update({ deleteAt });
      logger.info("Reported post already gone", { category });
      return;
    }
    const postSnapshot = reportPostSnapshot(post);
    const expiresAt = post.expiresAt instanceof Timestamp ? post.expiresAt.toMillis() : 0;
    if (expiresAt <= Date.now() || post.status !== "active") {
      await event.data.ref.update({ deleteAt, postSnapshot });
      logger.info("Reported post no longer active", { category });
      return;
    }

    const config = await serverConfig();
    let unsafeCredible: boolean | null = null;
    let verdictFields: Record<string, unknown> = {};
    if (category === "unsafe") {
      const { verdict, model } = config.moderationAiEnabled
        ? await checkUnsafe(postId, post, cleanReason(report.reason), config)
        : { verdict: null, model: null };
      unsafeCredible = isCredibleUnsafe(verdict, config.unsafeConfidenceMin);
      verdictFields = {
        aiVerdict: !config.moderationAiEnabled ? "disabled"
          : verdict ? (unsafeCredible ? "credible" : "notCredible") : "unavailable",
        aiConfidence: verdict?.confidence ?? null,
        aiConcern: verdict?.concern ?? null,
        aiRationale: verdict?.rationale ?? null,
        aiModel: model,
      };
      logger.info("Unsafe report checked", {
        verdict: verdict ? (unsafeCredible ? "credible" : "notCredible") : "unavailable",
        confidence: verdict?.confidence ?? null,
        concern: verdict?.concern ?? null,
      });
      if (unsafeCredible) {
        await event.data.ref.update({ ...verdictFields, deleteAt, postSnapshot, countsTowardThreshold: false });
        await removePost(postId, post, {
          category: "unsafe",
          strike: true,
          push: { title: UNSAFE_PUSH_TITLE, body: UNSAFE_PUSH_BODY, kind: "postRemoved" },
        }, config);
        return;
      }
    }

    const counts = countsTowardThreshold(category, unsafeCredible);
    await event.data.ref.update({ ...verdictFields, deleteAt, postSnapshot, countsTowardThreshold: counts });
    if (category === "offensive") {
      await pushToAdmins(config, {
        title: "New report to review",
        body: `${CATEGORY_LABELS[category]} report on a live post.`,
        kind: "adminReview",
      });
    }
    if (!counts) return;

    const countingReports = await db.collection("reports")
      .where("postId", "==", postId)
      .where("countsTowardThreshold", "==", true)
      .count()
      .get();
    const total = countingReports.data().count;
    logger.info("Report counted", { category, total });
    if (reachesRemovalThreshold(total, config.reportRemovalThreshold)) {
      await removePost(postId, post, { category, strike: true }, config);
    }
  },
);

/**
 * Asks the model chain whether the unsafe reason is credible. A null verdict on any failure, which never removes a
 * post; `model` is the model that answered, if any.
 */
async function checkUnsafe(postId: string, post: Record<string, unknown>, reason: string,
  config: ServerConfig): Promise<{ verdict: UnsafeVerdict | null; model: string | null }> {
  if (!reason) return { verdict: null, model: null };
  const slots = Array.isArray(post.photoSlots) ? post.photoSlots.filter((s): s is number => typeof s === "number") : [];
  const coverSlot = slots.length > 0 ? Math.min(...slots) : (post.hasPhoto === true ? 0 : null);

  let photo: Buffer | null = null;
  if (coverSlot !== null) {
    try {
      [photo] = await getStorage().bucket().file(photoPath(postId, coverSlot)).download();
    } catch (error) {
      logger.warn("Couldn't load the reported photo", { code: errorCode(error) });
    }
  }

  const prompt = unsafeCheckPrompt(postFacts(post), reason, photo !== null);
  try {
    const answer = await generateWithFallback({
      models: modelChain(config.moderationAiModelName, config.moderationAiFallbackModelNames),
      location: config.moderationAiLocation,
      timeoutMs: config.moderationAiTimeoutMs,
      contents: [{
        role: "user",
        parts: [
          ...(photo ? [{ inlineData: { mimeType: "image/jpeg", data: photo.toString("base64") } }] : []),
          { text: prompt },
        ],
      }],
      config: { temperature: 0, responseMimeType: "application/json", responseJsonSchema: UNSAFE_VERDICT_SCHEMA },
    });
    const verdict = parseUnsafeVerdict(answer.text);
    if (!verdict) logger.warn("Unsafe check returned an invalid response", { model: answer.model });
    return { verdict, model: answer.model };
  } catch (error) {
    logger.warn("Unsafe check failed", { code: errorCode(error) });
    return { verdict: null, model: null };
  }
}
