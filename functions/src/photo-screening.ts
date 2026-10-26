/**
 * Screening for every published post (decision 12): one Gemini call through the Agent Platform with all the post's
 * photos and everything the poster wrote (title, description, items, cautions, room, names), so abusive words the
 * word filter misses ("fuckkk", "motherfuck") are caught too. AI failure, a timeout or invalid JSON keep the post.
 * Logs the outcome, problem, latency and model, never content.
 */
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { type ServerConfig, modelChain } from "./config-logic.js";
import { generateWithFallback } from "./genai.js";
import {
  SCREENING_SCHEMA,
  type ScreeningProblem,
  type ScreeningVerdict,
  parseScreeningVerdict,
  photoPath,
  photoSlots,
  screeningPrompt,
  screeningText,
  shouldRemove,
} from "./photo-screening-logic.js";
import { errorCode } from "./recipients.js";

/** The problem when the post should be removed, else null. Never throws. */
export async function screenPost(postId: string, post: Record<string, unknown>,
  config: ServerConfig): Promise<ScreeningProblem | null> {
  if (!config.photoScreeningEnabled || !config.moderationAiEnabled) return null;
  const photos = await loadPhotos(postId, photoSlots(post));
  const text = screeningText(post);
  if (photos.length === 0 && text.length === 0) return null;

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
          ...(text.length > 0 ? [{ text: `<post_text>\n${text}\n</post_text>` }] : []),
          { text: screeningPrompt(photos.length, text.length > 0) },
        ],
      }],
      config: { temperature: 0, responseMimeType: "application/json", responseJsonSchema: SCREENING_SCHEMA },
    });
    model = answer.model;
    verdict = parseScreeningVerdict(answer.text);
  } catch (error) {
    logger.warn("Post screening failed; post kept", { code: errorCode(error), latencyMs: Date.now() - start });
    return null;
  }
  const remove = shouldRemove(verdict, config.photoScreeningConfidenceMin);
  logger.info("Post screened", {
    outcome: verdict === null ? "invalid" : remove ? "removed" : "kept",
    problem: verdict?.problem ?? null,
    confidence: verdict?.confidence ?? null,
    photos: photos.length,
    hasText: text.length > 0,
    latencyMs: Date.now() - start,
    model,
  });
  return remove && verdict ? verdict.problem : null;
}

/** The photos that could be downloaded; a missing one is logged and skipped. */
async function loadPhotos(postId: string, slots: readonly number[]): Promise<Buffer[]> {
  if (slots.length === 0) return [];
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
  return downloads.filter((data): data is Buffer => data !== null);
}
