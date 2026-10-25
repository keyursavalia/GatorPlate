import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { ContentFilter, checkPost, hasPrice, postTexts, tokens } from "../lib/content-filter.js";
import { SEED_TERMS, SEED_TRADING_TERMS } from "../lib/content-filter-seed.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/content-filter-cases.json", import.meta.url), "utf8"));
const appSeed = JSON.parse(readFileSync(
  new URL("../../GatorPlate/Resources/content-filter-seed.json", import.meta.url), "utf8"));

test("the functions seed matches the app's bundled seed", () => {
  assert.deepEqual(appSeed.terms, [...SEED_TERMS]);
  assert.deepEqual(appSeed.tradingTerms, [...SEED_TRADING_TERMS]);
});

test("every seed case matches the fixture", () => {
  const filter = new ContentFilter(SEED_TERMS, SEED_TRADING_TERMS);
  for (const { text, kind } of fixture.seedCases) assert.equal(filter.check(text), kind, JSON.stringify(text));
});

test("every custom case matches the fixture", () => {
  const filter = new ContentFilter(fixture.customLists.terms, fixture.customLists.tradingTerms);
  for (const { text, kind } of fixture.customCases) assert.equal(filter.check(text), kind, JSON.stringify(text));
});

test("seed terms are normalized and none is a common food word", () => {
  for (const term of [...SEED_TERMS, ...SEED_TRADING_TERMS]) assert.ok(tokens(term).length > 0, term);
  const filter = new ContentFilter(SEED_TERMS, []);
  for (const food of ["chicken breast", "nuts", "buns", "balls", "sausage", "wiener", "cracker", "naked", "redskin"]) {
    assert.equal(filter.check(food), null, food);
  }
});

test("normalization folds case, accents, leetspeak, punctuation and long repeats", () => {
  assert.deepEqual(tokens("Ça VA, 5h00t!!"), ["ca", "va", "shoot"]);
  assert.deepEqual(tokens("sooooo  goood"), ["soo", "good"]);
  assert.deepEqual(tokens("  "), []);
});

test("prices are found on the original text", () => {
  assert.equal(hasPrice("$5"), true);
  assert.equal(hasPrice("2 Bucks"), true);
  assert.equal(hasPrice("Room 5"), false);
  assert.equal(hasPrice("$$$"), false);
});

test("the server checks every user-written post field", () => {
  const post = {
    title: "Pizza", description: "Cheese", items: [{ name: "Slice" }, "ignored"], cautions: ["Hot"],
    locationDetail: "Room 1", authorName: "Sam", orgName: "Club", buildingId: "lib",
  };
  assert.deepEqual(postTexts(post), ["Pizza", "Cheese", "Slice", "Hot", "Room 1", "Sam", "Club"]);
  const filter = new ContentFilter(SEED_TERMS, SEED_TRADING_TERMS);
  assert.equal(checkPost(filter, post), null);
  assert.equal(checkPost(filter, { ...post, cautions: ["$3 each"] }), "trading");
  assert.equal(checkPost(filter, { ...post, orgName: "Shit Club" }), "terms");
});
