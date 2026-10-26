import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { banHoldId, heldBanToApply, shouldHoldBan } from "../lib/ban-hold-logic.js";

const NOW = Date.UTC(2026, 9, 21, 12, 0, 0);
const DAY = 86_400_000;

test("hold IDs are the lowercase hex SHA-256 of the normalized email", () => {
  const expected = createHash("sha256").update("test.user@example.org").digest("hex");
  assert.equal(banHoldId("  Test.User@Example.org "), expected);
  assert.match(expected, /^[0-9a-f]{64}$/);
  assert.equal(banHoldId(""), null);
  assert.equal(banHoldId(undefined), null);
  assert.notEqual(banHoldId("a@example.org"), banHoldId("b@example.org"));
});

test("only a running pause is held", () => {
  assert.equal(shouldHoldBan(NOW + DAY, NOW), true);
  assert.equal(shouldHoldBan(NOW - 1, NOW), false);
  assert.equal(shouldHoldBan(null, NOW), false);
});

test("a hold applies to a new account but never shortens its own pause", () => {
  assert.equal(heldBanToApply(NOW + 3 * DAY, null, NOW), NOW + 3 * DAY);
  assert.equal(heldBanToApply(NOW + 3 * DAY, NOW + DAY, NOW), NOW + 3 * DAY);
  assert.equal(heldBanToApply(NOW + 3 * DAY, NOW + 5 * DAY, NOW), null);
  assert.equal(heldBanToApply(NOW - DAY, null, NOW), null);
  assert.equal(heldBanToApply(null, null, NOW), null);
});
