import assert from "node:assert/strict";
import { test } from "node:test";
import { healthAlertBody } from "../lib/ai-health-logic.js";

const chain = (label, ...statuses) => ({ label, models: statuses.map(([name, status]) => ({ name, status })) });

test("no push while every primary is available or unknown", () => {
  assert.equal(healthAlertBody([chain("app", ["a", "available"]), chain("server", ["b", "unknown"])]), null);
  assert.equal(healthAlertBody([chain("app", ["a", "available"], ["b", "unavailable"])]), null);
});

test("a retired primary with a working fallback names the model and key", () => {
  assert.equal(healthAlertBody([chain("app", ["gemini-old", "unavailable"], ["gemini-new", "available"])]),
    "gemini-old isn't available. Update ai_model_name in Remote Config.");
  assert.equal(healthAlertBody([chain("server", ["gemini-old", "unavailable"], ["gemini-new", "unknown"])]),
    "gemini-old isn't available. Update moderation_ai_model_name in Remote Config.");
});

test("an entire dead chain says no configured model works", () => {
  assert.equal(healthAlertBody([chain("server", ["x", "unavailable"], ["y", "unavailable"])]),
    "No configured server model works (x first). Update moderation_ai_model_name in Remote Config.");
});
