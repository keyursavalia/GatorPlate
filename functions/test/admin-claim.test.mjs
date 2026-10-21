import assert from "node:assert/strict";
import { test } from "node:test";
import { nextAdminClaims } from "../lib/admin-claim-logic.js";

test("listed accounts get the admin claim, others lose it", () => {
  assert.deepEqual(nextAdminClaims(undefined, "a", true, ["a"]), { admin: true });
  assert.equal(nextAdminClaims({ admin: true }, "a", true, ["a"]), null);
  assert.deepEqual(nextAdminClaims({ admin: true, other: 1 }, "a", true, []), { other: 1 });
  assert.equal(nextAdminClaims(undefined, "b", true, ["a"]), null);
});

test("guests are never admins, even if listed", () => {
  assert.equal(nextAdminClaims(undefined, "a", false, ["a"]), null);
  assert.deepEqual(nextAdminClaims({ admin: true }, "a", false, ["a"]), {});
});
