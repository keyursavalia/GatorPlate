import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { alertSubtitle, dietPhrase, keywordMatches, matchesFilters, normalizeFilters, words } from "../lib/filters.js";

// The same fixture runs in the app's Swift harness (AlertFilterMatcher).
const cases = JSON.parse(readFileSync(new URL("./fixtures/alert-filter-cases.json", import.meta.url), "utf8"));

test("shared fixture: every case matches", () => {
  assert.ok(cases.length >= 30);
  for (const testCase of cases) {
    assert.equal(matchesFilters(testCase.post, testCase.filters), testCase.expected, testCase.name);
  }
});

test("malformed or 'all' filters normalize to null (all free food)", () => {
  assert.equal(normalizeFilters(undefined), null);
  assert.equal(normalizeFilters(null), null);
  assert.equal(normalizeFilters([]), null);
  assert.equal(normalizeFilters({ mode: "all", diets: ["vegan"] }), null);
  assert.equal(normalizeFilters({ mode: "custom", foods: [""] }), null);
  assert.equal(normalizeFilters({ mode: "custom", foods: Array(11).fill("x") }), null);
  assert.deepEqual(normalizeFilters({ mode: "custom", foods: [" boba "] }).foods, ["boba"]);
});

test("words fold case and diacritics and split on punctuation", () => {
  assert.deepEqual(words("Crème Brûlée, Domino's!"), ["creme", "brulee", "domino", "s"]);
  assert.deepEqual(words("  "), []);
});

test("keywords match whole words with an optional trailing s", () => {
  assert.equal(keywordMatches("pizza", "Veggie pizzas"), true);
  assert.equal(keywordMatches("pie", "pierogi"), false);
  assert.equal(keywordMatches("pie", "apple pies"), true);
  assert.equal(keywordMatches("red bull", "red, bull"), true);
  assert.equal(keywordMatches("red bull", "bull red"), false);
  assert.equal(keywordMatches("", "anything"), false);
});

test("diet phrase reflects the items", () => {
  assert.equal(dietPhrase({ items: [{ dietary: "vegan" }] }), "Vegan");
  assert.equal(dietPhrase({ items: [{ dietary: "vegan" }, { dietary: "vegetarian" }] }), "Vegetarian");
  assert.equal(dietPhrase({ items: [{ dietary: "vegetarian" }, { dietary: "nonVegetarian" }] }), "Vegetarian options");
  assert.equal(dietPhrase({ items: [{ dietary: "vegan" }, { dietary: "unknown" }] }), "Vegan options");
  assert.equal(dietPhrase({ items: [{ dietary: "nonVegetarian" }] }), null);
});

test("subtitle is built from post facts in campus time", () => {
  // 2026-10-15 19:40 PDT
  const expiresAt = new Date("2026-10-16T02:40:00Z");
  const subtitle = alertSubtitle({
    items: [{ dietary: "vegetarian" }, { dietary: "nonVegetarian" }],
    locationName: "Student Services Building",
    expiresAt,
  });
  assert.equal(subtitle.replace(/ /g, " "), "Vegetarian options · Student Services Building · until 7:40 PM");
  assert.equal(alertSubtitle({ items: [{ dietary: "nonVegetarian" }] }), null);
  const timestamp = { toMillis: () => expiresAt.getTime() };
  assert.ok(alertSubtitle({ items: [], locationName: "Library", expiresAt: timestamp }).startsWith("Library · until 7:40"));
  const long = alertSubtitle({ items: [{ dietary: "vegan" }], locationName: "x".repeat(80) });
  assert.ok([...long].length <= 100);
});
