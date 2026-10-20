/**
 * Moderation from the Firebase console: the owner creates an `adminActions/{id}` doc (`removePost`,
 * `resolveAppeal`, `liftBan`, `clearStrikes`), this function does the work and writes `status` ("done" / "failed"),
 * a short `result` and `processedAt`. Runs once per doc (a transaction claims it), never throws, and logs the action
 * and outcome only. Clients can't read or write `adminActions` (no rules match).
 */
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { type AdminAction, appealDecisionPush, parseAdminAction } from "./admin-actions-logic.js";
import type { ServerConfig } from "./config-logic.js";
import { pushToUser, removePost } from "./moderation-actions.js";
import { errorCode } from "./recipients.js";
import { serverConfig } from "./runtimeConfig.js";

export const onAdminActionCreated = onDocumentCreated(
  { document: "adminActions/{actionId}", region: "us-central1", retry: false, memory: "512MiB", timeoutSeconds: 60 },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const ref = snapshot.ref;
    const db = getFirestore();
    // Events can arrive more than once: only the first run claims the doc.
    const claimed = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(ref);
      if (!current.exists || current.get("status") !== undefined) return false;
      transaction.update(ref, { status: "processing" });
      return true;
    });
    if (!claimed) {
      logger.info("Admin action already processed");
      return;
    }

    const parsed = parseAdminAction(snapshot.data());
    if (!parsed.ok) {
      await finish(ref, "failed", parsed.error);
      logger.warn("Admin action rejected", { reason: parsed.error });
      return;
    }
    const action = parsed.value;
    try {
      const config = await serverConfig();
      const result = await run(action, config);
      await finish(ref, result.ok ? "done" : "failed", result.message);
      logger.info("Admin action processed", { action: action.action, ok: result.ok });
    } catch (error) {
      await finish(ref, "failed", `Error ${String(errorCode(error) ?? "unknown")}`);
      logger.error("Admin action failed", { action: action.action, code: errorCode(error) });
    }
  },
);

async function finish(ref: FirebaseFirestore.DocumentReference, status: "done" | "failed", result: string) {
  await ref.update({ status, result: result.slice(0, 200), processedAt: FieldValue.serverTimestamp() });
}

type Outcome = { ok: boolean; message: string };

async function run(action: AdminAction, config: ServerConfig): Promise<Outcome> {
  switch (action.action) {
    case "removePost":
      return removePostAction(action.postId, action.strike, config);
    case "resolveAppeal":
      return resolveAppeal(action.uid, action.decision, action.clearStrikes, action.note);
    case "liftBan":
      await liftBan(action.uid, action.clearStrikes);
      return { ok: true, message: action.clearStrikes ? "Ban lifted and strikes cleared" : "Ban lifted" };
    case "clearStrikes":
      await clearStrikes(action.uid);
      return { ok: true, message: "Strikes cleared" };
  }
}

async function removePostAction(postId: string, strike: boolean, config: ServerConfig): Promise<Outcome> {
  const post = (await getFirestore().collection("posts").doc(postId).get()).data();
  if (!post) return { ok: false, message: "Post not found (already removed or ended)" };
  // No push to the poster for admin removals.
  const removed = await removePost(postId, post, { category: "admin", strike }, config);
  return removed ? { ok: true, message: strike ? "Post removed with a strike" : "Post removed" }
    : { ok: false, message: "Post was already removed" };
}

/** Deletes the running ban on both docs; optionally empties the strike history. */
async function liftBan(uid: string, clearStrikesToo: boolean) {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const batch = db.batch();
  if ((await userRef.get()).exists) batch.update(userRef, { postingBannedUntil: FieldValue.delete() });
  batch.set(db.collection("moderation").doc(uid), {
    bannedUntil: FieldValue.delete(),
    ...(clearStrikesToo ? { removals: [] } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await batch.commit();
}

async function clearStrikes(uid: string) {
  await getFirestore().collection("moderation").doc(uid).set(
    { removals: [], updatedAt: FieldValue.serverTimestamp() }, { merge: true });
}

async function resolveAppeal(uid: string, decision: "upheld" | "denied", clearStrikesToo: boolean,
  note: string | null): Promise<Outcome> {
  const db = getFirestore();
  const appealRef = db.collection("appeals").doc(uid);
  if (!(await appealRef.get()).exists) return { ok: false, message: "No appeal for this uid" };

  let bannedUntilMs: number | null = null;
  if (decision === "upheld") {
    await liftBan(uid, clearStrikesToo);
  } else {
    const ban = (await db.collection("users").doc(uid).get()).get("postingBannedUntil");
    bannedUntilMs = ban instanceof Timestamp && ban.toMillis() > Date.now() ? ban.toMillis() : null;
  }
  await appealRef.update({
    resolution: decision,
    resolvedAt: FieldValue.serverTimestamp(),
    resolutionNote: note ?? FieldValue.delete(),
  });
  const push = appealDecisionPush(decision, bannedUntilMs);
  await pushToUser(uid, { ...push, kind: "appealResolved" });
  return { ok: true, message: decision === "upheld" ? "Appeal upheld; ban lifted" : "Appeal denied" };
}
