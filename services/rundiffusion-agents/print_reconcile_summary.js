#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

function summaryPathFromArgs(argv, env) {
  const cliPath = argv[2] && !argv[2].startsWith("--") ? argv[2] : "";
  if (cliPath) return path.resolve(cliPath);
  if (env.OPENCLAW_RECONCILE_SUMMARY_PATH) return env.OPENCLAW_RECONCILE_SUMMARY_PATH;

  const stateDir = env.OPENCLAW_STATE_DIR || "/data/.openclaw";
  return path.join(stateDir, "reconcile-summary.json");
}

function readSummary(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  return JSON.parse(raw);
}

function formatList(values) {
  return Array.isArray(values) && values.length ? values.join(", ") : "none";
}

function yesNo(value) {
  return value ? "yes" : "no";
}

function computeStatus(summary) {
  if (!summary || typeof summary !== "object") return "unknown";
  if (!summary.reconciliationCompleted) return "starting";
  if (summary.globalConfigAligned === false) return "broken";
  if (Array.isArray(summary.warningMessages) && summary.warningMessages.length) return "warning";
  return "healthy";
}

function formatSummary(summary, filePath) {
  const repairedFileCount = Array.isArray(summary.repairedFiles) ? summary.repairedFiles.length : 0;
  const backupCount = Array.isArray(summary.backups) ? summary.backups.length : 0;

  return [
    `status: ${computeStatus(summary)}`,
    `artifact: ${filePath}`,
    `completed: ${yesNo(summary.reconciliationCompleted)}`,
    `completedAt: ${summary.reconciliationCompletedAt || "none"}`,
    `accessMode: ${summary.gatewayAccessMode || "unknown"}`,
    `gatewayAuthMode: ${summary.gatewayAuthMode || "unknown"}`,
    `proxyAuthEnabled: ${yesNo(summary.openClawProxyAuthEnabled)}`,
    `allowedOrigins: ${formatList(summary.controlUiAllowedOrigins)}`,
    `configAligned: ${yesNo(summary.globalConfigAligned)}`,
    `configChanged: ${yesNo(summary.globalConfigChanged)}`,
    `repairs: files=${repairedFileCount} backups=${backupCount}`,
    `warnings: ${formatList(summary.warningMessages)}`,
  ].join("\n");
}

if (require.main === module) {
  const filePath = summaryPathFromArgs(process.argv, process.env);

  try {
    const summary = readSummary(filePath);
    process.stdout.write(`${formatSummary(summary, filePath)}\n`);
  } catch (error) {
    process.stderr.write(`could not read reconciliation summary at ${filePath}: ${error.message}\n`);
    process.exit(1);
  }
}

module.exports = {
  computeStatus,
  formatSummary,
  readSummary,
  summaryPathFromArgs,
};
