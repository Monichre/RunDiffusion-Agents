#!/usr/bin/env node

const { readSummary, summaryPathFromArgs } = require("./print_reconcile_summary");

function arrayCount(value) {
  return Array.isArray(value) ? value.length : 0;
}

function evaluateSummary(summary) {
  if (!summary || typeof summary !== "object") {
    return { verdict: "broken", exitCode: 2, reason: "invalid-summary" };
  }

  if (!summary.reconciliationCompleted) {
    return { verdict: "broken", exitCode: 2, reason: "reconciliation-incomplete" };
  }

  if (summary.globalConfigAligned === false) {
    return { verdict: "broken", exitCode: 2, reason: "global-config-misaligned" };
  }

  if (arrayCount(summary.warningMessages) > 0) {
    return {
      verdict: "warning",
      exitCode: 1,
      reason: `warnings=${arrayCount(summary.warningMessages)}`,
    };
  }

  return { verdict: "healthy", exitCode: 0, reason: "ok" };
}

function formatVerdict(summary, evaluation, filePath) {
  return [
    evaluation.verdict,
    `path=${filePath}`,
    `accessMode=${summary?.gatewayAccessMode || "unknown"}`,
    `gatewayAuthMode=${summary?.gatewayAuthMode || "unknown"}`,
    `proxyAuthEnabled=${summary?.openClawProxyAuthEnabled ? "yes" : "no"}`,
    `configAligned=${summary?.globalConfigAligned ? "yes" : "no"}`,
    `reason=${evaluation.reason}`,
  ].join(" ");
}

if (require.main === module) {
  const filePath = summaryPathFromArgs(process.argv, process.env);

  try {
    const summary = readSummary(filePath);
    const evaluation = evaluateSummary(summary);
    process.stdout.write(`${formatVerdict(summary, evaluation, filePath)}\n`);
    process.exit(evaluation.exitCode);
  } catch (error) {
    process.stdout.write(`broken path=${filePath} reason=artifact-unreadable\n`);
    process.stderr.write(`could not read reconciliation summary at ${filePath}: ${error.message}\n`);
    process.exit(2);
  }
}

module.exports = {
  evaluateSummary,
  formatVerdict,
};
