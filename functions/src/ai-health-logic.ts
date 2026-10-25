/**
 * Pure part of the daily AI health check: turns per-model availability into the admin push (or none).
 * Only "unavailable" (the backend said 404 / not found) counts; a check that failed for another reason says nothing
 * about the model and never pushes.
 */

export type ModelStatus = "available" | "unavailable" | "unknown";

export interface ChainHealth {
  /** "app" (Firebase AI Logic, checked against the Agent Platform as a proxy) or "server" (moderation). */
  label: string;
  /** In chain order; the first is the primary. */
  models: { name: string; status: ModelStatus }[];
}

export const HEALTH_PUSH_TITLE = "AI model needs attention";

/** The push body, or null when every primary model is fine (or couldn't be checked). */
export function healthAlertBody(chains: readonly ChainHealth[]): string | null {
  const lines: string[] = [];
  for (const chain of chains) {
    const primary = chain.models[0];
    if (!primary || primary.status !== "unavailable") continue;
    const allGone = chain.models.every((model) => model.status === "unavailable");
    const key = chain.label === "app" ? "ai_model_name" : "moderation_ai_model_name";
    lines.push(allGone
      ? `No configured ${chain.label} model works (${primary.name} first). Update ${key} in Remote Config.`
      : `${primary.name} isn't available. Update ${key} in Remote Config.`);
  }
  return lines.length > 0 ? lines.join(" ") : null;
}
