/**
 * Remote Config for the functions. Server-only settings come from the **server** template (`getServerTemplate`);
 * settings shared with the app (model names, content-filter lists) come from the **client** template's default
 * values (`getTemplate`), so each shared list is edited in one place. Both are cached per instance and never
 * throw: any failure logs a code and returns the parsed defaults (or the last good values).
 * The runtime service account needs "Remote Config Viewer" (`roles/cloudconfig.viewer`).
 */
import { getRemoteConfig, type ServerTemplate } from "firebase-admin/remote-config";
import { logger } from "firebase-functions";
import {
  type RawConfig,
  type ServerConfig,
  type SharedConfig,
  SERVER_KEYS,
  SHARED_KEYS,
  parseServerConfig,
  parseSharedConfig,
  serverDefaultStrings,
} from "./config-logic.js";
import { errorCode } from "./recipients.js";

/** A server template change takes effect within this long. */
const SERVER_RELOAD_MS = 60_000;
/** Shared lists (e.g. the content filter) refresh this often. */
const SHARED_RELOAD_MS = 5 * 60_000;

let serverTemplate: ServerTemplate | null = null;
let serverLoadedAt = 0;
let serverLoading: Promise<void> | null = null;

/** Loads or reloads the server template at most once per interval; concurrent callers share one load. */
async function refreshServerTemplate(): Promise<void> {
  if (serverTemplate && Date.now() - serverLoadedAt < SERVER_RELOAD_MS) return;
  serverLoading ??= (async () => {
    try {
      if (serverTemplate) {
        await serverTemplate.load();
      } else {
        serverTemplate = await getRemoteConfig().getServerTemplate({ defaultConfig: serverDefaultStrings() });
      }
    } catch (error) {
      // Keeps the cached template (if any); retried after the interval.
      logger.warn("Server config load failed", { code: errorCode(error) });
    } finally {
      serverLoadedAt = Date.now();
      serverLoading = null;
    }
  })();
  await serverLoading;
}

/** Server-only settings, validated. Defaults when Remote Config is unreachable. */
export async function serverConfig(): Promise<ServerConfig> {
  await refreshServerTemplate();
  const raw: RawConfig = {};
  if (serverTemplate) {
    try {
      const evaluated = serverTemplate.evaluate();
      for (const key of Object.values(SERVER_KEYS)) raw[key] = evaluated.getString(key);
    } catch (error) {
      logger.warn("Server config evaluate failed", { code: errorCode(error) });
    }
  }
  const { config, invalidKeys } = parseServerConfig(raw);
  if (invalidKeys.length > 0) logger.warn("Server config has invalid values", { invalidKeys });
  return config;
}

let shared: { config: SharedConfig; loadedAt: number } | null = null;
let sharedLoading: Promise<SharedConfig> | null = null;

/** Settings shared with the app, from the client template's default values (conditions are ignored). */
export async function sharedConfig(): Promise<SharedConfig> {
  if (shared && Date.now() - shared.loadedAt < SHARED_RELOAD_MS) return shared.config;
  sharedLoading ??= (async () => {
    const raw: RawConfig = {};
    let loaded = false;
    try {
      const template = await getRemoteConfig().getTemplate();
      for (const key of Object.values(SHARED_KEYS)) {
        const defaultValue = template.parameters[key]?.defaultValue;
        // `{ useInAppDefault: true }` (or no default) means "use the code default".
        if (defaultValue && "value" in defaultValue) raw[key] = defaultValue.value;
      }
      loaded = true;
    } catch (error) {
      logger.warn("Shared config load failed", { code: errorCode(error) });
    }
    const { config, invalidKeys } = parseSharedConfig(raw);
    if (invalidKeys.length > 0) logger.warn("Shared config has invalid values", { invalidKeys });
    // A failed load keeps the last good values, if any, and is retried after the interval.
    const result = !loaded && shared ? shared.config : config;
    shared = { config: result, loadedAt: Date.now() };
    return result;
  })();
  try {
    return await sharedLoading;
  } finally {
    sharedLoading = null;
  }
}
