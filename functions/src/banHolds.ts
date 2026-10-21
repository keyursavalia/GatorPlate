/**
 * A profile gained an email (sign-up or guest upgrade): if that email has a ban hold from a deleted account, the
 * remaining pause moves onto this account (`users/{uid}.postingBannedUntil` and `moderation/{uid}.bannedUntil`), so
 * the app's Posting paused sheet and appeal work as usual. `firestore.rules` also refuses posts while a hold is active,
 * covering the seconds before this runs. Logs whether a hold applied, never the email or the hash.
 */
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { banHoldId, heldBanToApply } from "./ban-hold-logic.js";

export const onProfileEmailSet = onDocumentWritten(
  { document: "users/{uid}", region: "us-central1", retry: false },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const email = after?.email;
    if (!after || typeof email !== "string" || before?.email === email) return;
    const holdId = banHoldId(email);
    if (!holdId) return;

    const db = getFirestore();
    const hold = await db.collection("banHolds").doc(holdId).get();
    const holdUntil = hold.get("bannedUntil");
    const existing = after.postingBannedUntil;
    const banUntil = heldBanToApply(holdUntil instanceof Timestamp ? holdUntil.toMillis() : null,
      existing instanceof Timestamp ? existing.toMillis() : null, Date.now());
    if (banUntil === null) return;

    const uid = event.params.uid;
    const bannedUntil = Timestamp.fromMillis(banUntil);
    const batch = db.batch();
    batch.update(db.collection("users").doc(uid), { postingBannedUntil: bannedUntil });
    batch.set(db.collection("moderation").doc(uid),
      { bannedUntil, bannedAt: FieldValue.serverTimestamp(), heldFromDeletedAccount: true }, { merge: true });
    await batch.commit();
    logger.info("Ban hold applied to a new account");
  },
);
