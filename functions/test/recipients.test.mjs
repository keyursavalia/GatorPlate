import assert from "node:assert/strict";
import { test } from "node:test";
import { alertBody, chunk, isQuietHours, recipientIds } from "../lib/recipients.js";

const id = (n) => `installation-id-${n}`;
// 2026-10-08 12:00 PDT and 23:30 PDT / 06:59 PDT / 07:00 PDT.
const noon = new Date("2026-10-08T19:00:00Z");
const lateNight = new Date("2026-10-09T06:30:00Z");
const beforeSeven = new Date("2026-10-09T13:59:00Z");
const seven = new Date("2026-10-09T14:00:00Z");

test("quiet hours are 11 PM to 7 AM campus time", () => {
  assert.equal(isQuietHours(noon), false);
  assert.equal(isQuietHours(lateNight), true);
  assert.equal(isQuietHours(beforeSeven), true);
  assert.equal(isQuietHours(seven), false);
  assert.equal(isQuietHours(new Date("2026-10-09T06:00:00Z")), true); // 23:00 PDT
  assert.equal(isQuietHours(new Date("2026-10-09T05:59:00Z")), false); // 22:59 PDT
});

test("excludes the author, opted-out users and invalid IDs", () => {
  const subscribers = [
    { uid: "author", notificationsEnabled: true, fcmInstallationId: id(1) },
    { uid: "a", notificationsEnabled: true, fcmInstallationId: id(2) },
    { uid: "b", notificationsEnabled: false, fcmInstallationId: id(3) },
    { uid: "c", notificationsEnabled: true },
    { uid: "d", notificationsEnabled: true, fcmInstallationId: 42 },
    { uid: "e", notificationsEnabled: "true", fcmInstallationId: id(5) },
  ];
  assert.deepEqual(recipientIds(subscribers, "author", undefined, noon), [id(2)]);
});

test("excludes the author's device even under another account, and dedupes", () => {
  const subscribers = [
    { uid: "a", notificationsEnabled: true, fcmInstallationId: id(9) },
    { uid: "b", notificationsEnabled: true, fcmInstallationId: id(2) },
    { uid: "c", notificationsEnabled: true, fcmInstallationId: id(2) },
  ];
  // The author has alerts off (not in the query) but their device ID is still known from their profile.
  assert.deepEqual(recipientIds(subscribers, "author", id(9), noon), [id(2)]);
});

test("quiet hours mute only users who chose them", () => {
  const subscribers = [
    { uid: "a", notificationsEnabled: true, fcmInstallationId: id(1), quietHoursEnabled: true },
    { uid: "b", notificationsEnabled: true, fcmInstallationId: id(2), quietHoursEnabled: false },
    { uid: "c", notificationsEnabled: true, fcmInstallationId: id(3) },
  ];
  assert.deepEqual(recipientIds(subscribers, "x", undefined, lateNight), [id(2), id(3)]);
  assert.deepEqual(recipientIds(subscribers, "x", undefined, noon), [id(1), id(2), id(3)]);
});

test("alert body is the trimmed one-line title, capped at 120 characters", () => {
  assert.equal(alertBody("  FREE: Pad Thai\n - SSB 201 "), "FREE: Pad Thai - SSB 201");
  assert.equal(alertBody(""), null);
  assert.equal(alertBody(undefined), null);
  const long = alertBody("FREE: " + "x".repeat(200));
  assert.equal([...long].length, 120);
  assert.ok(long.endsWith("…"));
});

test("chunks into FCM-sized batches", () => {
  assert.deepEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assert.equal(chunk(Array.from({ length: 1001 }, (_, i) => i), 500).length, 3);
  assert.deepEqual(chunk([], 500), []);
});
