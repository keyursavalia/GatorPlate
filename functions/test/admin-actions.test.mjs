import assert from "node:assert/strict";
import { test } from "node:test";
import { appealDecisionPush, isUid, isUserAppealWrite, parseAdminAction } from "../lib/admin-actions-logic.js";

const UID = "gbHzRCvpr2elR5750jtWbrCnqOf1";
const POST = "AbCdEfGhIjKlMnOpQrSt";

test("removePost needs a post ID and defaults to a strike", () => {
  assert.deepEqual(parseAdminAction({ action: "removePost", postId: POST }),
    { ok: true, value: { action: "removePost", postId: POST, strike: true, note: null } });
  assert.deepEqual(parseAdminAction({ action: "removePost", postId: POST, strike: false, note: " spam " }),
    { ok: true, value: { action: "removePost", postId: POST, strike: false, note: "spam" } });
  assert.equal(parseAdminAction({ action: "removePost" }).ok, false);
  assert.equal(parseAdminAction({ action: "removePost", postId: "../users/x" }).ok, false);
  assert.equal(parseAdminAction({ action: "removePost", postId: POST, strike: "yes" }).ok, false);
});

test("resolveAppeal needs a uid and a decision", () => {
  assert.deepEqual(parseAdminAction({ action: "resolveAppeal", uid: UID, decision: "upheld", clearStrikes: true }),
    { ok: true, value: { action: "resolveAppeal", uid: UID, decision: "upheld", clearStrikes: true, note: null } });
  assert.deepEqual(parseAdminAction({ action: "resolveAppeal", uid: UID, decision: "denied", note: "Photos showed people." }).value,
    { action: "resolveAppeal", uid: UID, decision: "denied", clearStrikes: false, note: "Photos showed people." });
  assert.equal(parseAdminAction({ action: "resolveAppeal", decision: "upheld" }).ok, false);
  assert.equal(parseAdminAction({ action: "resolveAppeal", uid: UID }).ok, false);
  assert.equal(parseAdminAction({ action: "resolveAppeal", uid: UID, decision: "maybe" }).ok, false);
});

test("a note over 200 characters is rejected", () => {
  const result = parseAdminAction({ action: "resolveAppeal", uid: UID, decision: "denied", note: "x".repeat(201) });
  assert.deepEqual(result, { ok: false, error: "note must be at most 200 characters" });
  assert.equal(parseAdminAction({ action: "resolveAppeal", uid: UID, decision: "denied", note: "x".repeat(200) }).ok, true);
  assert.equal(parseAdminAction({ action: "removePost", postId: POST, note: 5 }).ok, false);
});

test("liftBan and clearStrikes need a uid", () => {
  assert.deepEqual(parseAdminAction({ action: "liftBan", uid: UID }).value, { action: "liftBan", uid: UID, clearStrikes: false });
  assert.deepEqual(parseAdminAction({ action: "clearStrikes", uid: UID }).value, { action: "clearStrikes", uid: UID });
  for (const uid of [undefined, "", "a/b", " padded", "x".repeat(129), 42]) {
    assert.equal(parseAdminAction({ action: "liftBan", uid }).ok, false, String(uid));
    assert.equal(parseAdminAction({ action: "clearStrikes", uid }).ok, false, String(uid));
  }
  assert.equal(isUid(UID), true);
});

test("unknown actions and non-objects are rejected", () => {
  assert.equal(parseAdminAction({ action: "deleteEverything" }).ok, false);
  assert.equal(parseAdminAction({}).ok, false);
  assert.equal(parseAdminAction(null).ok, false);
  assert.equal(parseAdminAction("removePost").ok, false);
});

test("appeal decision pushes", () => {
  assert.equal(appealDecisionPush("upheld", null).body, "Your appeal was accepted. You can post again.");
  const denied = appealDecisionPush("denied", Date.UTC(2026, 9, 27, 19, 0, 0));
  assert.equal(denied.body, "Your appeal was reviewed. Posting stays paused until Oct 27, 12:00 PM.");
  assert.equal(appealDecisionPush("denied", null).body, "Your appeal was reviewed. Posting stays paused for now.");
});

test("only a user's new or changed appeal alerts the admins", () => {
  const appeal = { message: "Please review, these were real food posts.", bannedUntil: 1 };
  assert.equal(isUserAppealWrite(undefined, appeal), true);
  assert.equal(isUserAppealWrite(appeal, { ...appeal, resolution: "denied" }), false);
  assert.equal(isUserAppealWrite(appeal, appeal), false);
  assert.equal(isUserAppealWrite(appeal, { ...appeal, bannedUntil: 2 }), true);
  assert.equal(isUserAppealWrite(appeal, undefined), false);
});
