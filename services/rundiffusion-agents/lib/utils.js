"use strict";

const fs = require("node:fs");

function normalizeString(value) {
  return String(value || "").trim();
}

function safeReadJson(filePath, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function ensureObject(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) return value;
  return {};
}

function parseCsvList(value) {
  return normalizeString(value)
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function envFlagEnabled(value, defaultValue = false) {
  const normalized = normalizeString(value).toLowerCase();
  if (!normalized) return defaultValue;
  return ["1", "true", "yes", "on"].includes(normalized);
}

module.exports = {
  ensureObject,
  envFlagEnabled,
  normalizeString,
  parseCsvList,
  safeReadJson,
};
