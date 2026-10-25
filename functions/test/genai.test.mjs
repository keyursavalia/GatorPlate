import assert from "node:assert/strict";
import { test } from "node:test";
import { ApiError } from "@google/genai";
import { isModelUnavailableError, tryModels } from "../lib/genai.js";

const apiError = (status, message) => new ApiError({ status, message });
const retired = () => apiError(404,
  '{"error":{"code":404,"message":"Publisher Model `projects/p/locations/global/publishers/google/models/gemini-0` was not found or your project does not have access to it.","status":"NOT_FOUND"}}');

test("404 and NOT_FOUND mean the model is unavailable", () => {
  assert.equal(isModelUnavailableError(retired()), true);
  assert.equal(isModelUnavailableError({ status: 404, message: "" }), true);
  assert.equal(isModelUnavailableError(new Error("got status: NOT_FOUND")), true);
});

test("a 400 naming the model as unsupported, deprecated or retired means unavailable", () => {
  for (const message of [
    "models/gemini-x is not found for API version v1beta",
    "Model gemini-x is not supported for generateContent",
    "The model gemini-3.5-flash has been deprecated",
    "This model was retired on 2026-10-01",
  ]) {
    assert.equal(isModelUnavailableError(apiError(400, message)), true, message);
  }
});

test("other errors keep their own handling", () => {
  assert.equal(isModelUnavailableError(apiError(429, "Resource exhausted")), false);
  assert.equal(isModelUnavailableError(apiError(500, "Internal error")), false);
  assert.equal(isModelUnavailableError(apiError(503, "The model is overloaded")), false);
  assert.equal(isModelUnavailableError(apiError(400, "Invalid JSON payload")), false);
  assert.equal(isModelUnavailableError(apiError(400, "Request contains an invalid argument: thinking_level")), false);
  assert.equal(isModelUnavailableError(new DOMException("This operation was aborted", "AbortError")), false);
  assert.equal(isModelUnavailableError(null), false);
  assert.equal(isModelUnavailableError("NOT_FOUND"), false);
});

test("the chain stops at the first model that answers", async () => {
  const tried = [];
  const answer = await tryModels(["a", "b", "c"], 1000, async ({ model }) => {
    tried.push(model);
    return `from ${model}`;
  });
  assert.deepEqual(answer, { text: "from a", model: "a" });
  assert.deepEqual(tried, ["a"]);
});

test("unavailable models are skipped in order and fallbacks are reported", async () => {
  const tried = [];
  const fallbacks = [];
  const answer = await tryModels(["old", "older", "good", "unused"], 1000, async ({ model }) => {
    tried.push(model);
    if (model !== "good") throw retired();
    return "ok";
  }, (from, to) => fallbacks.push(`${from}->${to}`));
  assert.deepEqual(answer, { text: "ok", model: "good" });
  assert.deepEqual(tried, ["old", "older", "good"]);
  assert.deepEqual(fallbacks, ["old->older", "older->good"]);
});

test("any other error ends the chain at once", async () => {
  const tried = [];
  await assert.rejects(tryModels(["a", "b"], 1000, async ({ model }) => {
    tried.push(model);
    throw apiError(429, "quota");
  }), (error) => error.status === 429);
  assert.deepEqual(tried, ["a"]);
});

test("an exhausted chain throws the last unavailable error", async () => {
  await assert.rejects(tryModels(["a", "b"], 1000, async () => {
    throw retired();
  }), (error) => error.status === 404);
});

test("an empty chain throws", async () => {
  await assert.rejects(tryModels([], 1000, async () => "never"));
});

test("the total deadline aborts the attempt", async () => {
  await assert.rejects(tryModels(["slow"], 30, ({ signal }) => new Promise((_, reject) => {
    signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
  })), (error) => error.name === "AbortError");
});
