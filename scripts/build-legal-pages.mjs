#!/usr/bin/env node
/**
 * Builds the public legal pages for Firebase Hosting from the same Markdown the app shows, so the two never drift:
 *   GatorPlate/Resources/TermsOfUse.md    -> hosting/public/terms/index.html
 *   GatorPlate/Resources/PrivacyPolicy.md -> hosting/public/privacy/index.html
 * plus hosting/public/support/index.html and a small hosting/public/index.html linking all three.
 * Handles the subset `LegalDocument.parse` handles: "# " title, "## " headings, "- " bullets, "1. " numbered items,
 * "---" separators (ignored), paragraphs, **bold** and `code`.
 * [TEAM NAME] and [CONTACT EMAIL] come from `AppConfig.swift` (teamName, supportEmail). No dependencies.
 * Run: node scripts/build-legal-pages.mjs (also the Hosting predeploy hook).
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const appConfig = readFileSync(join(root, "GatorPlate/App/AppConfig.swift"), "utf8");

function configString(name) {
  const match = appConfig.match(new RegExp(`static let ${name} = "([^"]+)"`));
  if (!match) throw new Error(`AppConfig.${name} not found`);
  return match[1];
}

const teamName = configString("teamName");
const supportEmail = configString("supportEmail");
const appName = configString("appName");

function escapeHtml(text) {
  return text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

function substitute(text) {
  const result = text.replaceAll("[TEAM NAME]", teamName).replaceAll("[CONTACT EMAIL]", supportEmail);
  if (result.includes("[TEAM NAME]") || result.includes("[CONTACT EMAIL]")) throw new Error("Placeholder left");
  return result;
}

/** Escapes, then applies **bold**, `code`, and links the support email. */
function inline(text) {
  let html = escapeHtml(substitute(text));
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/`(.+?)`/g, "<code>$1</code>");
  html = html.replaceAll(escapeHtml(supportEmail), `<a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a>`);
  return html;
}

/** Markdown subset -> { title, html }. */
function convert(markdown) {
  const sections = [[]];
  let title = appName;
  let paragraph = [];
  let list = null; // { tag, items }

  const current = () => sections[sections.length - 1];
  const flushParagraph = () => {
    if (paragraph.length) current().push(`<p>${inline(paragraph.join(" "))}</p>`);
    paragraph = [];
  };
  const flushList = () => {
    if (list) current().push(`<${list.tag}>${list.items.map((item) => `<li>${item}</li>`).join("")}</${list.tag}>`);
    list = null;
  };
  const addItem = (tag, html) => {
    flushParagraph();
    if (list?.tag !== tag) {
      flushList();
      list = { tag, items: [] };
    }
    list.items.push(html);
  };

  for (const rawLine of markdown.split("\n")) {
    const line = rawLine.trim();
    if (line === "") {
      flushParagraph();
      flushList();
    } else if (line === "---") {
      flushParagraph();
      flushList();
      sections.push([]);
    } else if (line.startsWith("# ")) {
      flushParagraph();
      flushList();
      title = substitute(line.slice(2));
    } else if (line.startsWith("## ")) {
      flushParagraph();
      flushList();
      current().push(`<h2>${inline(line.slice(3))}</h2>`);
    } else if (line.startsWith("- ")) {
      addItem("ul", inline(line.slice(2)));
    } else if (/^\d+\. /.test(line)) {
      addItem("ol", inline(line.replace(/^\d+\. /, "")));
    } else {
      flushList();
      paragraph.push(line);
    }
  }
  flushParagraph();
  flushList();

  return { title, html: sections.flat().join("\n") };
}

function page(title, body, { home = false } = {}) {
  const nav = home ? "" : `<nav><a href="/">${escapeHtml(appName)}</a> · <a href="/terms">Terms</a> · <a href="/privacy">Privacy</a> · <a href="/support">Support</a></nav>`;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<style>
  :root { color-scheme: light dark; --text: #1c1c1e; --muted: #5b5b60; --bg: #ffffff; --accent: #5b3fb5; }
  @media (prefers-color-scheme: dark) {
    :root { --text: #f2f2f7; --muted: #aeaeb2; --bg: #111113; --accent: #a993ec; }
  }
  body { margin: 0; background: var(--bg); color: var(--text);
         font: 17px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 24px 16px 64px; }
  nav { max-width: 720px; margin: 0 auto; padding: 16px 16px 0; font-size: 15px; color: var(--muted); }
  h1 { font-size: 1.8rem; line-height: 1.25; margin: 0.5rem 0 1rem; }
  h2 { font-size: 1.15rem; margin: 2rem 0 0.5rem; }
  a { color: var(--accent); }
  li { margin: 0.35rem 0; }
  code { font-size: 0.9em; }
  .muted { color: var(--muted); }
</style>
</head>
<body>
${nav}
<main>
<h1>${escapeHtml(title)}</h1>
${body}
</main>
</body>
</html>
`;
}

function write(relativePath, html) {
  const path = join(root, "hosting/public", relativePath);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, html);
  console.log(`wrote hosting/public/${relativePath}`);
}

for (const [file, slug] of [["TermsOfUse.md", "terms"], ["PrivacyPolicy.md", "privacy"]]) {
  const { title, html } = convert(readFileSync(join(root, "GatorPlate/Resources", file), "utf8"));
  write(`${slug}/index.html`, page(title, html));
}

const email = `<a href="mailto:${escapeHtml(supportEmail)}">${escapeHtml(supportEmail)}</a>`;
write("support/index.html", page(`${appName} Support`, `
<p>${escapeHtml(appName)} is a free iOS app where people on the San Francisco State campus post leftover food from events, and
everyone else gets notified and finds it on a campus map. It is an independent student project, not an official
SF State app.</p>
<h2>Contact</h2>
<p>Email ${email}. We read every message. Reports of offensive posts are reviewed by a person within 24 hours.</p>
<h2>Report a post or block a poster</h2>
<ul>
<li>Open the post on the map, tap the <strong>More</strong> (⋯) button, then <strong>Report</strong> and pick a reason: Unsafe to eat, Offensive or inappropriate, Spam or misleading, or Selling or trading. Reporting needs an account with a verified email.</li>
<li>In the same menu, <strong>Block</strong> hides that poster's posts and alerts for you. They aren't told. Unblock people in Settings &gt; Safety &gt; Blocked people.</li>
</ul>
<h2>Delete your account</h2>
<p>In the app, go to Settings &gt; Account &gt; Delete account. This deletes your account, your posts and photos, the
reports you filed, your blocks, your appeal and your moderation records.</p>
<h2>Legal</h2>
<p><a href="/terms">Terms of Use</a> · <a href="/privacy">Privacy Policy</a></p>
`));

write("index.html", page(appName, `
<p>Leftover campus food, posted in seconds.</p>
<ul>
<li><a href="/support">Support</a></li>
<li><a href="/terms">Terms of Use</a></li>
<li><a href="/privacy">Privacy Policy</a></li>
</ul>
<p class="muted">Not an official San Francisco State University app.</p>
`, { home: true }));
