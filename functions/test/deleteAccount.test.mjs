import assert from "node:assert/strict";
import { test } from "node:test";
import { isPostId, isRecentLogin, photoPrefix, RECENT_LOGIN_SECONDS } from "../lib/deleteAccount.js";

test("delete needs a sign-in within the last 5 minutes", () => {
  const now = Date.UTC(2026, 9, 15, 12, 0, 0);
  const seconds = now / 1000;
  assert.equal(RECENT_LOGIN_SECONDS, 300);
  assert.equal(isRecentLogin(seconds - 299, now), true); // 4:59
  assert.equal(isRecentLogin(seconds - 300, now), true);
  assert.equal(isRecentLogin(seconds - 301, now), false); // 5:01
  assert.equal(isRecentLogin(seconds + 30, now), true); // small clock skew
  assert.equal(isRecentLogin(seconds + 120, now), false);
  assert.equal(isRecentLogin(undefined, now), false);
  assert.equal(isRecentLogin("1700000000", now), false);
  assert.equal(isRecentLogin(Number.NaN, now), false);
});

test("photo prefix covers the cover and slots 1-3, and never widens", () => {
  const id = "AbCdEfGhIjKlMnOpQrSt";
  assert.equal(photoPrefix(id), `postImages/${id}`);
  for (const name of [`${id}.jpg`, `${id}_1.jpg`, `${id}_2.jpg`, `${id}_3.jpg`]) {
    assert.ok(`postImages/${name}`.startsWith(photoPrefix(id)));
  }
  assert.equal(photoPrefix(""), null);
  assert.equal(photoPrefix("short"), null);
  assert.equal(photoPrefix(`${id}x`), null);
  assert.equal(photoPrefix("AbCdEfGhIjKlMnOpQr/."), null);
  assert.equal(isPostId(42), false);
});
