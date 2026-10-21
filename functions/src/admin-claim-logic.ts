/**
 * The `admin` custom claim follows the server Remote Config `admin_uids`: listed accounts get `admin: true`, everyone
 * else loses it. Rules read `request.auth.token.admin` to open reports, appeals and moderation records to admins.
 */

export type Claims = Record<string, unknown>;

/** The claims to set, or null when nothing changes. Other claims are kept. Guests (no email) are never admins. */
export function nextAdminClaims(current: Claims | undefined, uid: string, hasEmail: boolean,
  adminUids: readonly string[]): Claims | null {
  const claims = { ...(current ?? {}) };
  const shouldBeAdmin = hasEmail && adminUids.includes(uid);
  const isAdmin = claims.admin === true;
  if (shouldBeAdmin === isAdmin) return null;
  if (shouldBeAdmin) {
    claims.admin = true;
  } else {
    delete claims.admin;
  }
  return claims;
}
