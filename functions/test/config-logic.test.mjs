import assert from "node:assert/strict";
import { test } from "node:test";
import {
  SERVER_DEFAULTS,
  SERVER_KEYS,
  SHARED_DEFAULTS,
  isModelName,
  modelChain,
  parseServerConfig,
  parseSharedConfig,
  parseStringArray,
  serverDefaultStrings,
} from "../lib/config-logic.js";

test("empty input gives every server default and no invalid keys", () => {
  const { config, invalidKeys } = parseServerConfig({});
  assert.deepEqual(config, { ...SERVER_DEFAULTS });
  assert.deepEqual(invalidKeys, []);
  assert.equal(config.moderationAiModelName, "gemini-3.6-flash");
  assert.deepEqual(config.moderationAiFallbackModelNames, ["gemini-3.8-flash"]);
  assert.equal(config.reportRemovalThreshold, 3);
  assert.equal(config.banAfterRemovals, 4);
  assert.equal(config.banDays, 7);
  assert.equal(config.strikeWindowDays, 30);
  assert.equal(config.unsafeConfidenceMin, 0.7);
  assert.equal(config.photoScreeningConfidenceMin, 0.8);
  assert.equal(config.blockAdminAlertThreshold, 3);
  assert.deepEqual(config.adminUids, []);
});

test("blank strings count as missing", () => {
  const { config, invalidKeys } = parseServerConfig({ ban_days: "  ", moderation_ai_model_name: "" });
  assert.equal(config.banDays, 7);
  assert.equal(config.moderationAiModelName, "gemini-3.6-flash");
  assert.deepEqual(invalidKeys, []);
});

test("the server defaults round-trip through their Remote Config strings", () => {
  const strings = serverDefaultStrings();
  assert.equal(Object.keys(strings).length, Object.keys(SERVER_KEYS).length);
  assert.equal(strings.admin_uids, "[]");
  assert.equal(strings.moderation_ai_fallback_model_names, '["gemini-3.8-flash"]');
  const { config, invalidKeys } = parseServerConfig(strings);
  assert.deepEqual(config, { ...SERVER_DEFAULTS });
  assert.deepEqual(invalidKeys, []);
});

test("numbers clamp at both ends and are logged", () => {
  const low = parseServerConfig({
    report_removal_threshold: "1", ban_days: "0", strike_window_days: "1", ban_after_removals: "-3",
    unsafe_confidence_min: "0.1", moderation_ai_timeout_ms: "10", block_admin_alert_threshold: "0",
    photo_screening_confidence_min: "0",
  });
  assert.equal(low.config.reportRemovalThreshold, 2);
  assert.equal(low.config.banDays, 1);
  assert.equal(low.config.strikeWindowDays, 7);
  assert.equal(low.config.banAfterRemovals, 2);
  assert.equal(low.config.unsafeConfidenceMin, 0.5);
  assert.equal(low.config.moderationAiTimeoutMs, 5000);
  assert.equal(low.config.blockAdminAlertThreshold, 1);
  assert.equal(low.config.photoScreeningConfidenceMin, 0.5);
  assert.equal(low.invalidKeys.length, 8);

  const high = parseServerConfig({
    report_removal_threshold: "99", ban_days: "365", strike_window_days: "400", ban_after_removals: "50",
    unsafe_confidence_min: "1.5", moderation_ai_timeout_ms: "999999", block_admin_alert_threshold: "1000",
    photo_screening_confidence_min: "2",
  });
  assert.equal(high.config.reportRemovalThreshold, 10);
  assert.equal(high.config.banDays, 30);
  assert.equal(high.config.strikeWindowDays, 90);
  assert.equal(high.config.banAfterRemovals, 10);
  assert.equal(high.config.unsafeConfidenceMin, 0.99);
  assert.equal(high.config.moderationAiTimeoutMs, 45000);
  assert.equal(high.config.blockAdminAlertThreshold, 50);
  assert.equal(high.config.photoScreeningConfidenceMin, 0.99);
});

test("in-range values are used as is; integers are rounded", () => {
  const { config, invalidKeys } = parseServerConfig({
    report_removal_threshold: "5", ban_days: "3", unsafe_confidence_min: "0.85", moderation_ai_timeout_ms: "15000",
  });
  assert.equal(config.reportRemovalThreshold, 5);
  assert.equal(config.banDays, 3);
  assert.equal(config.unsafeConfidenceMin, 0.85);
  assert.equal(config.moderationAiTimeoutMs, 15000);
  assert.deepEqual(invalidKeys, []);
  const rounded = parseServerConfig({ report_removal_threshold: "4.4" });
  assert.equal(rounded.config.reportRemovalThreshold, 4);
  assert.deepEqual(rounded.invalidKeys, ["report_removal_threshold"]);
});

test("non-numbers and non-booleans fall back", () => {
  const { config, invalidKeys } = parseServerConfig({
    ban_days: "seven", report_removal_threshold: "NaN", moderation_ai_enabled: "yes", photo_screening_enabled: "FALSE",
  });
  assert.equal(config.banDays, 7);
  assert.equal(config.reportRemovalThreshold, 3);
  assert.equal(config.moderationAiEnabled, true);
  assert.equal(config.photoScreeningEnabled, false);
  assert.deepEqual(invalidKeys.sort(), ["ban_days", "moderation_ai_enabled", "report_removal_threshold"]);
});

test("model names are validated", () => {
  for (const name of ["gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-4-argon", "gemini-0-nonexistent"]) {
    assert.equal(isModelName(name), true, name);
  }
  for (const name of ["Gemini-3.6-flash", "gpt-5", "gemini-", "gemini-3.6 flash", "gemini-3.6/flash", "", 3]) {
    assert.equal(isModelName(name), false, String(name));
  }
});

test("an invalid model name falls back to the default", () => {
  const { config, invalidKeys } = parseServerConfig({ moderation_ai_model_name: "models/gemini-3.6-flash" });
  assert.equal(config.moderationAiModelName, "gemini-3.6-flash");
  assert.deepEqual(invalidKeys, ["moderation_ai_model_name"]);
});

test("fallbacks drop duplicates and the primary", () => {
  const { config, invalidKeys } = parseServerConfig({
    moderation_ai_model_name: "gemini-3.8-flash",
    moderation_ai_fallback_model_names: '["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.7-flash", "gemini-3.5-flash"]',
  });
  assert.deepEqual(config.moderationAiFallbackModelNames, ["gemini-3.7-flash", "gemini-3.5-flash"]);
  assert.deepEqual(invalidKeys, []);
});

test("the primary is removed from the default fallbacks too", () => {
  const { config } = parseServerConfig({ moderation_ai_model_name: "gemini-3.8-flash" });
  assert.deepEqual(config.moderationAiFallbackModelNames, []);
});

test("malformed or oversized fallback arrays fall back", () => {
  for (const raw of ["gemini-3.8-flash", "{}", "[1, 2]", '["gemini-3.8-flash", "bad name"]',
    '["gemini-a", "gemini-b", "gemini-c", "gemini-d", "gemini-e"]']) {
    const { config, invalidKeys } = parseServerConfig({ moderation_ai_fallback_model_names: raw });
    assert.deepEqual(config.moderationAiFallbackModelNames, ["gemini-3.8-flash"], raw);
    assert.deepEqual(invalidKeys, ["moderation_ai_fallback_model_names"], raw);
  }
});

test("model chains keep order without duplicates", () => {
  assert.deepEqual(modelChain("a", ["b", "a", "c", "b"]), ["a", "b", "c"]);
  assert.deepEqual(modelChain("a", []), ["a"]);
});

test("admin uids and locations are validated", () => {
  const good = parseServerConfig({ admin_uids: '["gbHzRCvpr2elR5750jtWbrCnqOf1"]', moderation_ai_location: "us-central1" });
  assert.deepEqual(good.config.adminUids, ["gbHzRCvpr2elR5750jtWbrCnqOf1"]);
  assert.equal(good.config.moderationAiLocation, "us-central1");
  const tooMany = JSON.stringify(Array.from({ length: 11 }, (_, i) => `uid${i}`));
  const bad = parseServerConfig({ admin_uids: tooMany, moderation_ai_location: "US Central" });
  assert.deepEqual(bad.config.adminUids, []);
  assert.equal(bad.config.moderationAiLocation, "global");
  assert.deepEqual(bad.invalidKeys.sort(), ["admin_uids", "moderation_ai_location"]);
});

test("string arrays parse defensively", () => {
  assert.deepEqual(parseStringArray('[" a ", "bb", ""]', 5, 10), ["a", "bb"]);
  assert.deepEqual(parseStringArray('["ab", "x", "' + "y".repeat(41) + '"]', 5, 40, 2), ["ab"]);
  assert.equal(parseStringArray("not json", 5, 10), null);
  assert.equal(parseStringArray('"text"', 5, 10), null);
  assert.equal(parseStringArray('["a", 1]', 5, 10), null);
  assert.equal(parseStringArray('["a","b","c"]', 2, 10), null);
});

test("shared defaults are the app's model chain and the bundled seed lists", () => {
  const { config, invalidKeys } = parseSharedConfig({});
  assert.equal(config.aiModelName, "gemini-3.6-flash");
  assert.deepEqual(config.aiFallbackModelNames, ["gemini-3.8-flash"]);
  assert.ok(config.contentFilterTerms.length >= 100);
  assert.ok(config.contentFilterTradingTerms.includes("venmo"));
  assert.deepEqual(config, { ...SHARED_DEFAULTS });
  assert.deepEqual(invalidKeys, []);
});

test("shared filter lists drop bad entries but reject a malformed list", () => {
  const ok = parseSharedConfig({ content_filter_terms: '["badword", "x", "two words"]' });
  assert.deepEqual(ok.config.contentFilterTerms, ["badword", "two words"]);
  const broken = parseSharedConfig({ content_filter_terms: "[oops", content_filter_trading_terms: "{}" });
  assert.deepEqual(broken.config.contentFilterTerms, SHARED_DEFAULTS.contentFilterTerms);
  assert.deepEqual(broken.config.contentFilterTradingTerms, SHARED_DEFAULTS.contentFilterTradingTerms);
  assert.deepEqual(broken.invalidKeys.sort(), ["content_filter_terms", "content_filter_trading_terms"]);
  const huge = JSON.stringify(Array.from({ length: 2001 }, (_, i) => `term${i}`));
  assert.deepEqual(parseSharedConfig({ content_filter_terms: huge }).invalidKeys, ["content_filter_terms"]);
});

test("the app's model chain parses like the server's", () => {
  const { config } = parseSharedConfig({
    ai_model_name: "gemini-0-nonexistent", ai_fallback_model_names: '["gemini-3.6-flash", "gemini-0-nonexistent"]',
  });
  assert.equal(config.aiModelName, "gemini-0-nonexistent");
  assert.deepEqual(config.aiFallbackModelNames, ["gemini-3.6-flash"]);
});
