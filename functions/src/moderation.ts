import { GoogleGenAI } from "@google/genai";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { isPostId, photoPrefix } from "./deleteAccount.js";
import {
  type ReportCategory,
  type UnsafeVerdict,
  UNSAFE_PUSH_BODY,
  UNSAFE_PUSH_TITLE,
  UNSAFE_VERDICT_SCHEMA,
  banEndMs,
  cleanReason,
  countsTowardThreshold,
  isCredibleUnsafe,
  isReportCategory,
  parseRemovals,
  parseUnsafeVerdict,
  postFacts,
  reachesRemovalThreshold,
  removalsInWindow,
  unsafeCheckPrompt,
} from "./moderation-logic.js";
import { errorCode, isAlreadyExists } from "./recipients.js";

/**
 * Model for the unsafe check, called through Vertex AI with the functions service account (no API key). Same
 * family as the app's AppConfig.geminiModelName. Needs the Vertex AI API enabled and the runtime service account
 * granted "Vertex AI User".
 */
const UNSAFE_CHECK_MODEL = "gemini-3.6-flash";
const VERTEX_LOCATION = "global";
/** An AI call that takes longer counts as "not credible", so the report still counts toward the threshold. */
const AI_TIMEOUT_MS = 20_000;
/** Removal markers live this long; a TTL policy on `deleteAt` removes them. */
const REMOVAL_MARKER_RETENTION_MS = 24 * 60 * 60 * 1000;

let genAI: GoogleGenAI | null = null;
function vertex(): GoogleGenAI {
  genAI ??= new GoogleGenAI({
    vertexai: true,
    project: process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT,
    location: VERTEX_LOCATION,
  });
  return genAI;
}

/** Storage path of one photo slot: `{id}.jpg` for the cover slot 0, `{id}_N.jpg` otherwise. */
function photoPath(postId: string, slot: number): string {
  return slot === 0 ? `postImages/${postId}.jpg` : `postImages/${postId}_${slot}.jpg`;
}

/**
 * New report -> maybe remove the post. Unsafe: the AI checks the reporter's reason against the post; credible
 * removes it and tells the poster. Otherwise (and for spam/misleading and trading) the report counts toward the
 * pooled threshold of 3 distinct reporters, which removes the post silently. Each removal is a strike; the 4th in
 * 30 days pauses the poster's posting for 7 days. Logs counts and verdicts only, never reasons or IDs.
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

    const db = getFirestore();
    const postSnapshot = await db.collection("posts").doc(postId).get();
    const post = postSnapshot.data();
    if (!post) {
      logger.info("Reported post already gone", { category });
      return;
    }
    const expiresAt = post.expiresAt instanceof Timestamp ? post.expiresAt.toMillis() : 0;
    if (expiresAt <= Date.now() || post.status !== "active") {
      logger.info("Reported post no longer active", { category });
      return;
    }

    let unsafeCredible: boolean | null = null;
    if (category === "unsafe") {
      const verdict = await checkUnsafe(postId, post, cleanReason(report.reason));
      unsafeCredible = isCredibleUnsafe(verdict);
      await event.data.ref.update({
        aiVerdict: verdict ? (unsafeCredible ? "credible" : "notCredible") : "unavailable",
        aiConfidence: verdict?.confidence ?? null,
        aiConcern: verdict?.concern ?? null,
        aiRationale: verdict?.rationale ?? null,
        aiModel: UNSAFE_CHECK_MODEL,
      });
      logger.info("Unsafe report checked", {
        verdict: verdict ? (unsafeCredible ? "credible" : "notCredible") : "unavailable",
        confidence: verdict?.confidence ?? null,
        concern: verdict?.concern ?? null,
      });
      if (unsafeCredible) {
        await removePost(postId, post, "unsafe", true);
        return;
      }
    }

    const counts = countsTowardThreshold(category, unsafeCredible);
    await event.data.ref.update({ countsTowardThreshold: counts });
    if (!counts) return;

    const countingReports = await db.collection("reports")
      .where("postId", "==", postId)
      .where("countsTowardThreshold", "==", true)
      .count()
      .get();
    const total = countingReports.data().count;
    logger.info("Report counted", { category, total });
    if (reachesRemovalThreshold(total)) {
      await removePost(postId, post, category, false);
    }
  },
);

/** Asks the model whether the unsafe reason is credible. Null on any failure, which never removes a post. */
async function checkUnsafe(postId: string, post: Record<string, unknown>, reason: string): Promise<UnsafeVerdict | null> {
  if (!reason) return null;
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
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), AI_TIMEOUT_MS);
  try {
    const response = await vertex().models.generateContent({
      model: UNSAFE_CHECK_MODEL,
      contents: [{
        role: "user",
        parts: [
          ...(photo ? [{ inlineData: { mimeType: "image/jpeg", data: photo.toString("base64") } }] : []),
          { text: prompt },
        ],
      }],
      config: {
        temperature: 0,
        responseMimeType: "application/json",
        responseJsonSchema: UNSAFE_VERDICT_SCHEMA,
        abortSignal: controller.signal,
      },
    });
    const verdict = parseUnsafeVerdict(response.text ?? "");
    if (!verdict) logger.warn("Unsafe check returned an invalid response");
    return verdict;
  } catch (error) {
    logger.warn("Unsafe check failed", { code: errorCode(error) });
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Removes a post once (marker first, so a second trigger stops), deletes its photos and the doc, records the
 * strike and bans the poster on the 4th removal in 30 days. Pushes "Your post was reported: Unsafe" when asked.
 */
async function removePost(postId: string, post: Record<string, unknown>, category: ReportCategory, notify: boolean) {
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
      return;
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
  if (!authorUid) return;

  const now = Date.now();
  const moderationRef = db.collection("moderation").doc(authorUid);
  const userRef = db.collection("users").doc(authorUid);
  const { removalCount, bannedUntilMs } = await db.runTransaction(async (transaction) => {
    const [moderation, user] = await Promise.all([transaction.get(moderationRef), transaction.get(userRef)]);
    const removals = removalsInWindow(
      [...parseRemovals(moderation.get("removals")), { postId, category, atMs: now }], now);
    const banEnd = banEndMs(removals.length, now);
    const existingBan = user.get("postingBannedUntil");
    const existingBanMs = existingBan instanceof Timestamp ? existingBan.toMillis() : 0;
    // Never shortens a ban already running.
    const bannedUntil = banEnd !== null && banEnd > existingBanMs ? banEnd : null;
    transaction.set(moderationRef, {
      removals,
      updatedAt: FieldValue.serverTimestamp(),
      ...(bannedUntil !== null ? { bannedUntil: Timestamp.fromMillis(bannedUntil), bannedAt: FieldValue.serverTimestamp() } : {}),
    }, { merge: true });
    if (bannedUntil !== null && user.exists) {
      transaction.update(userRef, { postingBannedUntil: Timestamp.fromMillis(bannedUntil) });
    }
    return { removalCount: removals.length, bannedUntilMs: bannedUntil };
  });
  logger.info("Post removed after reports", { category, removalsIn30Days: removalCount, banned: bannedUntilMs !== null });

  if (notify) await notifyUnsafeRemoval(authorUid);
}

/** "Your post was reported: Unsafe" to the poster's device, when they have one registered. */
async function notifyUnsafeRemoval(authorUid: string) {
  const user = await getFirestore().collection("users").doc(authorUid).get();
  const fid = user.get("fcmInstallationId");
  if (typeof fid !== "string" || fid.length === 0) {
    logger.info("Poster has no device for the unsafe notice");
    return;
  }
  try {
    const response = await getMessaging().sendEachForMulticast({
      fids: [fid],
      notification: { title: UNSAFE_PUSH_TITLE, body: UNSAFE_PUSH_BODY },
      data: { kind: "postRemoved" },
      apns: { payload: { aps: { alert: { title: UNSAFE_PUSH_TITLE, body: UNSAFE_PUSH_BODY }, sound: "default" } } },
    });
    logger.info("Unsafe notice sent", { sent: response.successCount });
  } catch (error) {
    logger.warn("Couldn't send the unsafe notice", { code: errorCode(error) });
  }
}
