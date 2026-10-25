/**
 * Callable `syncAdminClaim`: the app calls it once per account session. Sets or removes the caller's `admin` claim to
 * match `admin_uids` (server Remote Config), so admin access is granted and revoked from the console with no other
 * step. Returns whether the claim changed (the app then refreshes its ID token). Logs the outcome only.
 */
import { getAuth } from "firebase-admin/auth";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { nextAdminClaims } from "./admin-claim-logic.js";
import { serverConfig } from "./runtimeConfig.js";

export const syncAdminClaim = onCall({ region: "us-central1", enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  const config = await serverConfig();
  const user = await getAuth().getUser(uid);
  const claims = nextAdminClaims(user.customClaims, uid, typeof user.email === "string", config.adminUids);
  if (claims === null) return { changed: false };
  await getAuth().setCustomUserClaims(uid, claims);
  logger.info("Admin claim changed", { admin: claims.admin === true });
  return { changed: true };
});
