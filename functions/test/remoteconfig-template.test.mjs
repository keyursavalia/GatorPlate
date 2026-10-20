import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { SHARED_DEFAULTS, SHARED_KEYS, parseSharedConfig } from "../lib/config-logic.js";

const template = JSON.parse(readFileSync(new URL("../../remoteconfig.template.json", import.meta.url), "utf8"));
const swift = readFileSync(new URL("../../GatorPlate/Core/Models/RuntimeConfig.swift", import.meta.url), "utf8");

test("the client template has exactly the app's keys, each described", () => {
  const appKeys = [...swift.matchAll(/case \w+ = "([a-z_]+)"/g)].map((match) => match[1]).sort();
  assert.deepEqual(Object.keys(template.parameters).sort(), appKeys);
  for (const [key, parameter] of Object.entries(template.parameters)) {
    assert.ok(parameter.description.length > 20 && parameter.description.length <= 256, key);
    assert.ok(["STRING", "BOOLEAN", "NUMBER", "JSON"].includes(parameter.valueType), key);
  }
});

test("the template's shared defaults equal the functions' defaults", () => {
  const raw = Object.fromEntries(Object.values(SHARED_KEYS).map((key) => [key, template.parameters[key].defaultValue.value]));
  const { config, invalidKeys } = parseSharedConfig(raw);
  assert.deepEqual(invalidKeys, []);
  assert.deepEqual(config, { ...SHARED_DEFAULTS });
});
