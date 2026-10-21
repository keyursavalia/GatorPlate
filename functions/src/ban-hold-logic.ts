/**
 * Ban holds: when an account is deleted during a posting pause, `banHolds/{id}` keeps the pause end under a one-way
 * hash of the email, so a new account with the same email can't post until it ends. Only the remaining pause carries
 * over (not strikes). `firestore.rules` computes the same ID: `hashing.sha256(email.lower()).toHexString().lower()`.
 */
import { createHash } from "node:crypto";

/** Lowercase hex SHA-256 of the trimmed, lowercased email; null for a missing or blank email. */
export function banHoldId(email: unknown): string | null {
  if (typeof email !== "string") return null;
  const normalized = email.trim().toLowerCase();
  if (normalized.length === 0) return null;
  return createHash("sha256").update(normalized).digest("hex");
}

/** Whether a deleted account's pause should be held: only while it is still running. */
export function shouldHoldBan(bannedUntilMs: number | null, nowMs: number): boolean {
  return bannedUntilMs !== null && bannedUntilMs > nowMs;
}

/**
 * The pause end to give a new account with a held email, or null. Never shortens a pause the account already has.
 */
export function heldBanToApply(holdUntilMs: number | null, existingBanMs: number | null, nowMs: number): number | null {
  if (holdUntilMs === null || holdUntilMs <= nowMs) return null;
  if (existingBanMs !== null && existingBanMs >= holdUntilMs) return null;
  return holdUntilMs;
}
