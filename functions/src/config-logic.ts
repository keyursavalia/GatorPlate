/**
 * Pure parsing of Remote Config values for the functions (no Firebase imports, tested with `node --test`).
 * Every value is validated and clamped; anything invalid falls back to the in-code default, so a bad publish can
 * never remove posts or stop alerts. Mirrors the parameter catalog in docs/sprints/SPRINT-10 (A1) and
 * docs/06-OPERATIONS.md. The app's `RuntimeConfig.swift` parses the client keys the same way.
 */
import { SEED_TERMS, SEED_TRADING_TERMS } from "./content-filter-seed.js";

export type RawConfig = Record<string, string | undefined>;

/** `gemini-` then lowercase letters, digits, dots and dashes (e.g. `gemini-3.6-flash`). */
const MODEL_NAME = /^gemini-[a-z0-9][a-z0-9.-]{0,60}$/;
const LOCATION = /^[a-z0-9-]{2,30}$/;
export const MAX_FALLBACK_MODELS = 4;
export const MAX_ADMIN_UIDS = 10;
export const MAX_FILTER_TERMS = 2000;
export const MAX_TRADING_TERMS = 200;
export const FILTER_TERM_MIN_LENGTH = 2;
export const FILTER_TERM_MAX_LENGTH = 40;

// MARK: Server template (functions only)

export interface ServerConfig {
  moderationAiEnabled: boolean;
  moderationAiModelName: string;
  moderationAiFallbackModelNames: string[];
  moderationAiLocation: string;
  moderationAiTimeoutMs: number;
  unsafeConfidenceMin: number;
  reportRemovalThreshold: number;
  strikeWindowDays: number;
  banAfterRemovals: number;
  banDays: number;
  photoScreeningEnabled: boolean;
  photoScreeningConfidenceMin: number;
  blockAdminAlertThreshold: number;
  adminUids: string[];
  aiHealthCheckEnabled: boolean;
}

export const SERVER_DEFAULTS: Readonly<ServerConfig> = Object.freeze({
  moderationAiEnabled: true,
  moderationAiModelName: "gemini-3.6-flash",
  moderationAiFallbackModelNames: ["gemini-3.8-flash"],
  moderationAiLocation: "global",
  moderationAiTimeoutMs: 20_000,
  unsafeConfidenceMin: 0.7,
  reportRemovalThreshold: 3,
  strikeWindowDays: 30,
  banAfterRemovals: 4,
  banDays: 7,
  photoScreeningEnabled: true,
  photoScreeningConfidenceMin: 0.8,
  blockAdminAlertThreshold: 3,
  adminUids: [],
  aiHealthCheckEnabled: true,
});

/** Remote Config key for each server setting. */
export const SERVER_KEYS: Readonly<Record<keyof ServerConfig, string>> = Object.freeze({
  moderationAiEnabled: "moderation_ai_enabled",
  moderationAiModelName: "moderation_ai_model_name",
  moderationAiFallbackModelNames: "moderation_ai_fallback_model_names",
  moderationAiLocation: "moderation_ai_location",
  moderationAiTimeoutMs: "moderation_ai_timeout_ms",
  unsafeConfidenceMin: "unsafe_confidence_min",
  reportRemovalThreshold: "report_removal_threshold",
  strikeWindowDays: "strike_window_days",
  banAfterRemovals: "ban_after_removals",
  banDays: "ban_days",
  photoScreeningEnabled: "photo_screening_enabled",
  photoScreeningConfidenceMin: "photo_screening_confidence_min",
  blockAdminAlertThreshold: "block_admin_alert_threshold",
  adminUids: "admin_uids",
  aiHealthCheckEnabled: "ai_health_check_enabled",
});

// MARK: Shared keys (client template, read by the app and the functions)

export interface SharedConfig {
  aiModelName: string;
  aiFallbackModelNames: string[];
  contentFilterTerms: string[];
  contentFilterTradingTerms: string[];
}

export const SHARED_DEFAULTS: Readonly<SharedConfig> = Object.freeze({
  aiModelName: "gemini-3.6-flash",
  aiFallbackModelNames: ["gemini-3.8-flash"],
  contentFilterTerms: [...SEED_TERMS],
  contentFilterTradingTerms: [...SEED_TRADING_TERMS],
});

export const SHARED_KEYS: Readonly<Record<keyof SharedConfig, string>> = Object.freeze({
  aiModelName: "ai_model_name",
  aiFallbackModelNames: "ai_fallback_model_names",
  contentFilterTerms: "content_filter_terms",
  contentFilterTradingTerms: "content_filter_trading_terms",
});

export interface Parsed<T> {
  config: T;
  /** Keys whose remote value was unusable (fell back or was clamped). Key names only, for one log line. */
  invalidKeys: string[];
}

// MARK: Parsers

export function isModelName(value: unknown): value is string {
  return typeof value === "string" && MODEL_NAME.test(value);
}

/** `[primary, ...fallbacks]` without duplicates, in order. */
export function modelChain(primary: string, fallbacks: readonly string[]): string[] {
  return [...new Set([primary, ...fallbacks])];
}

/**
 * A JSON array of strings. Null when the value isn't a JSON array, has more than `max` entries, or holds a
 * non-string. Entries are trimmed; ones outside `itemMin`...`itemMax` characters are dropped.
 */
export function parseStringArray(json: string, max: number, itemMax: number, itemMin = 1): string[] | null {
  let value: unknown;
  try {
    value = JSON.parse(json);
  } catch {
    return null;
  }
  if (!Array.isArray(value) || value.length > max) return null;
  if (!value.every((item) => typeof item === "string")) return null;
  return (value as string[])
    .map((item) => item.trim())
    .filter((item) => item.length >= itemMin && item.length <= itemMax);
}

/** Reads one key with a parser; tracks the key as invalid when a present value isn't usable as is. */
class Reader {
  readonly invalidKeys: string[] = [];
  constructor(private readonly raw: RawConfig) {}

  private value(key: string): string | undefined {
    const value = this.raw[key];
    if (value === undefined) return undefined;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }

  bool(key: string, fallback: boolean): boolean {
    const value = this.value(key)?.toLowerCase();
    if (value === undefined) return fallback;
    if (value === "true") return true;
    if (value === "false") return false;
    this.invalidKeys.push(key);
    return fallback;
  }

  /** Out-of-range numbers are clamped (and logged); non-numbers fall back. */
  number(key: string, fallback: number, min: number, max: number, integer = false): number {
    const value = this.value(key);
    if (value === undefined) return fallback;
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      this.invalidKeys.push(key);
      return fallback;
    }
    const rounded = integer ? Math.round(parsed) : parsed;
    const clamped = Math.min(max, Math.max(min, rounded));
    if (clamped !== parsed) this.invalidKeys.push(key);
    return clamped;
  }

  matching(key: string, fallback: string, pattern: RegExp): string {
    const value = this.value(key);
    if (value === undefined) return fallback;
    if (pattern.test(value)) return value;
    this.invalidKeys.push(key);
    return fallback;
  }

  /** Fallback model names: every entry must be a model name; the primary and duplicates are removed. */
  fallbackModels(key: string, fallback: readonly string[], primary: string): string[] {
    const value = this.value(key);
    let names: string[] = [...fallback];
    if (value !== undefined) {
      const parsed = parseStringArray(value, MAX_FALLBACK_MODELS, 64);
      if (parsed && parsed.every(isModelName)) {
        names = parsed;
      } else {
        this.invalidKeys.push(key);
      }
    }
    return [...new Set(names)].filter((name) => name !== primary);
  }

  list(key: string, fallback: readonly string[], max: number, itemMax: number, itemMin = 1): string[] {
    const value = this.value(key);
    if (value === undefined) return [...fallback];
    const parsed = parseStringArray(value, max, itemMax, itemMin);
    if (parsed) return parsed;
    this.invalidKeys.push(key);
    return [...fallback];
  }
}

export function parseServerConfig(raw: RawConfig): Parsed<ServerConfig> {
  const read = new Reader(raw);
  const d = SERVER_DEFAULTS;
  const k = SERVER_KEYS;
  const moderationAiModelName = read.matching(k.moderationAiModelName, d.moderationAiModelName, MODEL_NAME);
  const config: ServerConfig = {
    moderationAiEnabled: read.bool(k.moderationAiEnabled, d.moderationAiEnabled),
    moderationAiModelName,
    moderationAiFallbackModelNames: read.fallbackModels(
      k.moderationAiFallbackModelNames, d.moderationAiFallbackModelNames, moderationAiModelName),
    moderationAiLocation: read.matching(k.moderationAiLocation, d.moderationAiLocation, LOCATION),
    moderationAiTimeoutMs: read.number(k.moderationAiTimeoutMs, d.moderationAiTimeoutMs, 5_000, 45_000, true),
    unsafeConfidenceMin: read.number(k.unsafeConfidenceMin, d.unsafeConfidenceMin, 0.5, 0.99),
    reportRemovalThreshold: read.number(k.reportRemovalThreshold, d.reportRemovalThreshold, 2, 10, true),
    strikeWindowDays: read.number(k.strikeWindowDays, d.strikeWindowDays, 7, 90, true),
    banAfterRemovals: read.number(k.banAfterRemovals, d.banAfterRemovals, 2, 10, true),
    banDays: read.number(k.banDays, d.banDays, 1, 30, true),
    photoScreeningEnabled: read.bool(k.photoScreeningEnabled, d.photoScreeningEnabled),
    photoScreeningConfidenceMin: read.number(k.photoScreeningConfidenceMin, d.photoScreeningConfidenceMin, 0.5, 0.99),
    blockAdminAlertThreshold: read.number(k.blockAdminAlertThreshold, d.blockAdminAlertThreshold, 1, 50, true),
    adminUids: read.list(k.adminUids, d.adminUids, MAX_ADMIN_UIDS, 128),
    aiHealthCheckEnabled: read.bool(k.aiHealthCheckEnabled, d.aiHealthCheckEnabled),
  };
  return { config, invalidKeys: read.invalidKeys };
}

export function parseSharedConfig(raw: RawConfig): Parsed<SharedConfig> {
  const read = new Reader(raw);
  const d = SHARED_DEFAULTS;
  const k = SHARED_KEYS;
  const aiModelName = read.matching(k.aiModelName, d.aiModelName, MODEL_NAME);
  const config: SharedConfig = {
    aiModelName,
    aiFallbackModelNames: read.fallbackModels(k.aiFallbackModelNames, d.aiFallbackModelNames, aiModelName),
    contentFilterTerms: read.list(k.contentFilterTerms, d.contentFilterTerms, MAX_FILTER_TERMS,
      FILTER_TERM_MAX_LENGTH, FILTER_TERM_MIN_LENGTH),
    contentFilterTradingTerms: read.list(k.contentFilterTradingTerms, d.contentFilterTradingTerms, MAX_TRADING_TERMS,
      FILTER_TERM_MAX_LENGTH, FILTER_TERM_MIN_LENGTH),
  };
  return { config, invalidKeys: read.invalidKeys };
}

/** The server defaults as Remote Config strings (`getServerTemplate({ defaultConfig })`). */
export function serverDefaultStrings(): Record<string, string> {
  return Object.fromEntries(
    (Object.keys(SERVER_KEYS) as (keyof ServerConfig)[]).map((field) => {
      const value = SERVER_DEFAULTS[field];
      return [SERVER_KEYS[field], Array.isArray(value) ? JSON.stringify(value) : String(value)];
    }),
  );
}
