import assert from "node:assert/strict";
import { test } from "node:test";
import {
  parseScreeningVerdict, photoPath, photoSlots, screeningPrompt, shouldRemove,
} from "../lib/photo-screening-logic.js";

test("verdicts are validated", () => {
  const good = { allowed: false, confidence: 0.92, problem: "person", photo: 2 };
  assert.deepEqual(parseScreeningVerdict(JSON.stringify(good)), good);
  assert.deepEqual(parseScreeningVerdict({ ...good, photo: 0 }), { ...good, photo: null });
  assert.deepEqual(parseScreeningVerdict({ ...good, photo: 9 }), { ...good, photo: null });
  assert.equal(parseScreeningVerdict("nope"), null);
  assert.equal(parseScreeningVerdict({ ...good, allowed: "no" }), null);
  assert.equal(parseScreeningVerdict({ ...good, confidence: 1.2 }), null);
  assert.equal(parseScreeningVerdict({ ...good, problem: "ugly" }), null);
});

test("removal needs not allowed, enough confidence and a named problem", () => {
  const verdict = { allowed: false, confidence: 0.8, problem: "person", photo: 1 };
  assert.equal(shouldRemove(verdict, 0.8), true);
  assert.equal(shouldRemove({ ...verdict, confidence: 0.79 }, 0.8), false);
  assert.equal(shouldRemove({ ...verdict, allowed: true }, 0.8), false);
  assert.equal(shouldRemove({ ...verdict, problem: "none" }, 0.8), false);
  assert.equal(shouldRemove({ ...verdict, problem: "none", confidence: 1 }, 0.5), false);
  assert.equal(shouldRemove(null, 0.5), false);
});

test("photo slots and paths", () => {
  assert.deepEqual(photoSlots({ photoSlots: [2, 0, 2, 7, "1"] }), [0, 2]);
  assert.deepEqual(photoSlots({ hasPhoto: true }), [0]);
  assert.deepEqual(photoSlots({ hasPhoto: false }), []);
  assert.equal(photoPath("abc", 0), "postImages/abc.jpg");
  assert.equal(photoPath("abc", 3), "postImages/abc_3.jpg");
});

test("the prompt allows hands and ordinary settings but not people", () => {
  const prompt = screeningPrompt(2);
  assert.ok(prompt.includes('2 photos, each labeled "Photo N:"'));
  assert.ok(prompt.includes("Hands holding or serving food are fine."));
  assert.ok(prompt.includes("person: a recognizable face"));
});
