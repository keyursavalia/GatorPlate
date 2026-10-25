#!/usr/bin/env node
/**
 * Seeds the Remote Config **server** template (namespace `firebase-server`) with every server parameter, its
 * description and its code default. The Firebase CLI and the Admin SDK can't publish server templates, so this uses
 * the REST API with Application Default Credentials (no new dependency).
 *
 *   gcloud auth application-default login
 *   cd functions && npm run build && node scripts/seed-server-config.mjs --project <project-id> [--admin-uids uid1,uid2] [--force]
 *
 * Existing parameters keep their current values unless --force is given (so it never undoes console edits).
 * Prints key names only.
 */
import { applicationDefault } from "firebase-admin/app";
import { SERVER_DEFAULTS, SERVER_KEYS } from "../lib/config-logic.js";

const DESCRIPTIONS = {
  moderation_ai_enabled: "AI for unsafe-report checks and photo screening. false: unsafe reports count toward the pool; photos aren't screened.",
  moderation_ai_model_name: "First Gemini model for moderation (Agent Platform / Vertex AI API). Must match gemini-[a-z0-9.-].",
  moderation_ai_fallback_model_names: "Moderation models tried in order when one is retired. JSON array, max 4.",
  moderation_ai_location: "Agent Platform location for moderation calls, e.g. global or us-central1.",
  moderation_ai_timeout_ms: "Total deadline for one moderation AI call, 5000-45000 ms (clamped). A timeout never removes a post.",
  unsafe_confidence_min: "An unsafe report removes the post only at or above this AI confidence, 0.5-0.99.",
  report_removal_threshold: "Distinct counting reports that remove a post, 2-10.",
  strike_window_days: "Removals count toward a posting pause for this many days, 7-90.",
  ban_after_removals: "Removals within the window that pause posting, 2-10.",
  ban_days: "Length of a posting pause, 1-30 days.",
  photo_screening_enabled: "Screen photos of every published post with Gemini before alerts. AI failure keeps the post.",
  photo_screening_confidence_min: "A screened photo removes the post only at or above this confidence, 0.5-0.99.",
  block_admin_alert_threshold: "Admins get one push once a poster is blocked by this many people, 1-50.",
  admin_uids: "Firebase uids that get admin pushes (offensive reports, appeals, blocks, AI health). JSON array, max 10.",
  ai_health_check_enabled: "Daily 8 AM check that the configured Gemini models still exist; pushes the admins if not.",
};

function arg(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const project = arg("project") ?? process.env.GCLOUD_PROJECT;
if (!project) {
  console.error("Pass --project <project-id>");
  process.exit(1);
}
const force = process.argv.includes("--force");
const adminUids = arg("admin-uids")?.split(",").map((uid) => uid.trim()).filter(Boolean);

const url = `https://firebaseremoteconfig.googleapis.com/v1/projects/${project}/namespaces/firebase-server/remoteConfig`;
const { access_token: token } = await applicationDefault().getAccessToken();
const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json; UTF-8" };

const current = await fetch(url, { headers });
if (!current.ok && current.status !== 404) {
  console.error(`Couldn't read the server template: HTTP ${current.status}`);
  process.exit(1);
}
const etag = current.ok ? current.headers.get("etag") ?? "*" : "*";
const template = current.ok ? await current.json() : {};
template.parameters ??= {};

const added = [];
const kept = [];
for (const [field, key] of Object.entries(SERVER_KEYS)) {
  const value = SERVER_DEFAULTS[field];
  let text = Array.isArray(value) ? JSON.stringify(value) : String(value);
  if (key === "admin_uids" && adminUids) text = JSON.stringify(adminUids);
  const valueType = Array.isArray(value) ? "JSON" : typeof value === "boolean" ? "BOOLEAN"
    : typeof value === "number" ? "NUMBER" : "STRING";
  const existing = template.parameters[key];
  if (existing && !force) {
    existing.description ??= DESCRIPTIONS[key];
    kept.push(key);
    continue;
  }
  template.parameters[key] = { defaultValue: { value: text }, description: DESCRIPTIONS[key], valueType };
  added.push(key);
}

const response = await fetch(url, { method: "PUT", headers: { ...headers, "If-Match": etag }, body: JSON.stringify(template) });
if (!response.ok) {
  console.error(`Publish failed: HTTP ${response.status} ${(await response.text()).slice(0, 300)}`);
  process.exit(1);
}
console.log(`Server template published. Set: ${added.join(", ") || "none"}. Kept: ${kept.join(", ") || "none"}.`);
