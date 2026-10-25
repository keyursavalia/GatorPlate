/**
 * The one place the functions call Gemini: the Agent Platform (Vertex AI API, `aiplatform.googleapis.com`) through
 * `@google/genai`, authenticated by the functions service account. No API key exists anywhere.
 * `generateWithFallback` walks the configured model chain, moving on only when a model is unavailable (retired,
 * renamed, not served in the location). Other errors and timeouts end the call, like before.
 */
import { type ContentListUnion, type GenerateContentConfig, GoogleGenAI } from "@google/genai";
import { logger } from "firebase-functions";

const clients = new Map<string, GoogleGenAI>();

/** A client per Agent Platform location, created once per instance. */
export function client(location: string): GoogleGenAI {
  let existing = clients.get(location);
  if (!existing) {
    existing = new GoogleGenAI({
      vertexai: true,
      project: process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT,
      location,
    });
    clients.set(location, existing);
  }
  return existing;
}

/**
 * True when the backend says the model doesn't exist or isn't served: HTTP 404 / `NOT_FOUND` ("Publisher Model …
 * was not found"), or a 400 that names the model as not found, unsupported, deprecated or retired.
 * False for quota (429), server errors, timeouts and everything else.
 */
export function isModelUnavailableError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const status = (error as { status?: unknown }).status;
  const rawMessage = (error as { message?: unknown }).message;
  const message = typeof rawMessage === "string" ? rawMessage : "";
  if (status === 404 || message.includes("NOT_FOUND")) return true;
  if (status !== 400) return false;
  const lower = message.toLowerCase();
  return lower.includes("model") &&
    (lower.includes("not found") || lower.includes("not supported") || lower.includes("deprecated") ||
      lower.includes("retired"));
}

/** One model attempt: resolves to the response text. Injected in tests. */
export type GenerateFn = (request: { model: string; signal: AbortSignal }) => Promise<string>;

export interface ModelAnswer {
  text: string;
  /** The model that actually answered (stored on reports, logged). */
  model: string;
}

/**
 * Tries each model in order within one total deadline. Stops at the first answer. A "model unavailable" error
 * moves to the next model; any other error (or the deadline) is thrown at once. Throws the last error when every
 * model is unavailable.
 */
export async function tryModels(models: readonly string[], timeoutMs: number, generate: GenerateFn,
  onFallback?: (from: string, to: string) => void): Promise<ModelAnswer> {
  if (models.length === 0) throw new Error("No AI model configured");
  const deadline = Date.now() + timeoutMs;
  let lastError: unknown = new Error("AI deadline passed");
  for (const [index, model] of models.entries()) {
    const remaining = deadline - Date.now();
    if (remaining <= 0) break;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), remaining);
    try {
      return { text: await generate({ model, signal: controller.signal }), model };
    } catch (error) {
      if (!isModelUnavailableError(error)) throw error;
      lastError = error;
      const next = models[index + 1];
      if (next) onFallback?.(model, next);
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastError;
}

export interface GenerateRequest {
  models: readonly string[];
  location: string;
  timeoutMs: number;
  contents: ContentListUnion;
  config: Omit<GenerateContentConfig, "abortSignal">;
}

/** `generateContent` over the model chain. Logs fallbacks with model names only. */
export function generateWithFallback(request: GenerateRequest): Promise<ModelAnswer> {
  return tryModels(request.models, request.timeoutMs, async ({ model, signal }) => {
    const response = await client(request.location).models.generateContent({
      model,
      contents: request.contents,
      config: { ...request.config, abortSignal: signal },
    });
    return response.text ?? "";
  }, (from, to) => logger.warn(`AI model fallback: ${from} -> ${to}`));
}
