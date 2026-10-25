/**
 * Checks `onPostCreated` runs on a new post before anyone is alerted: the content filter on every user-written field
 * (the app blocks first, so this catches modified clients or a list updated between edit and publish), then the AI
 * screening of the photos and the text (disguised profanity the word list misses). A post that fails is removed
 * without a strike and nobody is alerted. Abusive text is removed as `filtered`, a photo problem as `screened`.
 */
import { logger } from "firebase-functions";
import type { SharedConfig } from "./config-logic.js";
import { ContentFilter, checkPost } from "./content-filter.js";
import { removePost } from "./moderation-actions.js";
import { SCREENED_PUSH, TEXT_SCREENED_PUSH, isTextProblem } from "./photo-screening-logic.js";
import { screenPost } from "./photo-screening.js";
import { serverConfig, sharedConfig } from "./runtimeConfig.js";

let cachedFilter: { lists: SharedConfig; filter: ContentFilter } | null = null;

/** The filter for the current shared lists, rebuilt only when they change. */
function filterFor(lists: SharedConfig): ContentFilter {
  if (cachedFilter?.lists !== lists) {
    cachedFilter = { lists, filter: new ContentFilter(lists.contentFilterTerms, lists.contentFilterTradingTerms) };
  }
  return cachedFilter.filter;
}

/** True when the post passed and alerts may go out; false when it was removed. */
export async function passesPostChecks(postId: string, post: Record<string, unknown>): Promise<boolean> {
  const [shared, config] = await Promise.all([sharedConfig(), serverConfig()]);
  const verdict = checkPost(filterFor(shared), post);
  if (verdict) {
    logger.info("Post failed the text filter", { kind: verdict });
    await removePost(postId, post, { category: "filtered", strike: false }, config);
    return false;
  }
  const problem = await screenPost(postId, post, config);
  if (problem) {
    const isText = isTextProblem(problem);
    await removePost(postId, post, {
      category: isText ? "filtered" : "screened",
      strike: false,
      push: { ...(isText ? TEXT_SCREENED_PUSH : SCREENED_PUSH), kind: "postRemoved" },
    }, config);
    return false;
  }
  return true;
}
