/**
 * Photo screening for every published post (decision 12): one Gemini call through the Agent Platform with all the
 * post's photos. AI failure, a timeout or invalid JSON keep the post. Logs the outcome, problem, latency and model,
 * never content.
 */
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { type ServerConfig, modelChain } from "./config-logic.js";
import { generateWithFallback } from "./genai.js";
import {
  SCREENING_SCHEMA,
  type ScreeningVerdict,
  parseScreeningVerdict,
  photoPath,
  photoSlots,
  screeningPrompt,
  shouldRemove,
} from "./photo-screening-logic.js";
import { errorCode } from "./recipients.js";

/** True when the post should be removed. Never throws. */
export async function photosFailScreening(postId: string, post: Record<string, unknown>,
  config: ServerConfig): Promise<boolean> {
  if (!config.photoScreeningEnabled || !config.moderationAiEnabled) return false;
  const slots = photoSlots(post);
  if (slots.length === 0) return false;

  const bucket = getStorage().bucket();
  const downloads = await Promise.all(slots.map(async (slot) => {
    try {
      const [data] = await bucket.file(photoPath(postId, slot)).download();
      return data;
    } catch (error) {
      logger.warn("Couldn't load a photo to screen", { code: errorCode(error) });
      return null;
    }
  }));
  const photos = downloads.filter((data): data is Buffer => data !== null);
  if (photos.length === 0) return false;

  const start = Date.now();
  let verdict: ScreeningVerdict | null = null;
  let model: string | null = null;
  try {
    const answer = await generateWithFallback({
      models: modelChain(config.moderationAiModelName, config.moderationAiFallbackModelNames),
      location: config.moderationAiLocation,
      timeoutMs: config.moderationAiTimeoutMs,
      contents: [{
        role: "user",
        parts: [
          ...photos.flatMap((photo, index) => [
            { text: `Photo ${index + 1}:` },
            { inlineData: { mimeType: "image/jpeg", data: photo.toString("base64") } },
          ]),
          { text: screeningPrompt(photos.length) },
        ],
      }],
      config: { temperature: 0, responseMimeType: "application/json", responseJsonSchema: SCREENING_SCHEMA },
    });
    model = answer.model;
    verdict = parseScreeningVerdict(answer.text);
  } catch (error) {
    logger.warn("Photo screening failed; post kept", { code: errorCode(error), latencyMs: Date.now() - start });
    return false;
  }
  const remove = shouldRemove(verdict, config.photoScreeningConfidenceMin);
  logger.info("Photos screened", {
    outcome: verdict === null ? "invalid" : remove ? "removed" : "kept",
    problem: verdict?.problem ?? null,
    confidence: verdict?.confidence ?? null,
    photos: photos.length,
    latencyMs: Date.now() - start,
    model,
  });
  return remove;
}
