/**
 * Daily early warning for retired Gemini models: checks the server chain (moderation) and the app's chain
 * (`ai_model_name` + fallbacks from the client template) with `models.get` on the Agent Platform, and pushes the
 * admins when a primary model is gone. Limitation: the app calls Gemini through Firebase AI Logic (Gemini Developer
 * API), whose model list can differ from the Agent Platform's; the app's own fallback chain is the real protection.
 * Logs model names and statuses only.
 */
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { type ChainHealth, HEALTH_PUSH_TITLE, type ModelStatus, healthAlertBody } from "./ai-health-logic.js";
import { modelChain } from "./config-logic.js";
import { client, isModelUnavailableError } from "./genai.js";
import { pushToAdmins } from "./moderation-actions.js";
import { errorCode } from "./recipients.js";
import { serverConfig, sharedConfig } from "./runtimeConfig.js";

async function status(model: string, location: string): Promise<ModelStatus> {
  try {
    await client(location).models.get({ model });
    return "available";
  } catch (error) {
    if (isModelUnavailableError(error)) return "unavailable";
    logger.warn("Model check failed", { model, code: errorCode(error) });
    return "unknown";
  }
}

async function chainHealth(label: string, models: string[], location: string): Promise<ChainHealth> {
  const statuses = await Promise.all(models.map((model) => status(model, location)));
  return { label, models: models.map((name, index) => ({ name, status: statuses[index] })) };
}

export const aiHealthCheck = onSchedule(
  { schedule: "every day 08:00", timeZone: "America/Los_Angeles", region: "us-central1", retryCount: 0 },
  async () => {
    const [config, shared] = await Promise.all([serverConfig(), sharedConfig()]);
    if (!config.aiHealthCheckEnabled) {
      logger.info("AI health check off");
      return;
    }
    const chains = await Promise.all([
      chainHealth("server", modelChain(config.moderationAiModelName, config.moderationAiFallbackModelNames),
        config.moderationAiLocation),
      chainHealth("app", modelChain(shared.aiModelName, shared.aiFallbackModelNames), config.moderationAiLocation),
    ]);
    logger.info("AI health", Object.fromEntries(chains.map((chain) =>
      [chain.label, chain.models.map((model) => `${model.name}:${model.status}`)])));
    const body = healthAlertBody(chains);
    if (body) await pushToAdmins(config, { title: HEALTH_PUSH_TITLE, body, kind: "adminReview" });
  },
);
