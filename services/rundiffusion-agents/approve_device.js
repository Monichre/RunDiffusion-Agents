#!/usr/bin/env node

const { execFileSync } = require("node:child_process");
const readline = require("node:readline");

function escapeAnsi(value) {
  return String(value).replace(/\u001b\[[0-9;]*m/g, "");
}

function truncate(value, maxLength) {
  const text = String(value ?? "");
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`;
}

function formatTimestamp(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Date(value).toISOString();
  }

  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }

  return "unknown";
}

function requestIdOf(entry) {
  return String(entry?.requestId || entry?.id || entry?.deviceId || "").trim();
}

function requestCreatedAtOf(entry) {
  return entry?.requestedAtMs ?? entry?.createdAtMs ?? entry?.requestedAt ?? entry?.createdAt ?? null;
}

function requestRemoteIpOf(entry) {
  return String(entry?.remoteIp || entry?.ip || entry?.clientIp || "unknown").trim();
}

function requestClientLabelOf(entry) {
  const clientId = String(entry?.clientId || "unknown").trim();
  const clientMode = String(entry?.clientMode || "").trim();
  return clientMode ? `${clientId}/${clientMode}` : clientId;
}

function requestPlatformOf(entry) {
  return String(entry?.platform || entry?.userAgent || "unknown").trim();
}

function normalizePendingRequests(payload) {
  const pending = Array.isArray(payload?.pending) ? payload.pending : [];

  return pending
    .map((entry) => ({
      raw: entry,
      requestId: requestIdOf(entry),
      createdAt: formatTimestamp(requestCreatedAtOf(entry)),
      createdAtSortKey:
        typeof requestCreatedAtOf(entry) === "number" ? requestCreatedAtOf(entry) : 0,
      remoteIp: requestRemoteIpOf(entry),
      client: requestClientLabelOf(entry),
      platform: requestPlatformOf(entry),
      role: String(entry?.role || entry?.requestedRole || "operator").trim(),
      scopes: Array.isArray(entry?.scopes)
        ? entry.scopes
        : Array.isArray(entry?.requestedScopes)
          ? entry.requestedScopes
          : [],
    }))
    .filter((entry) => entry.requestId)
    .sort((left, right) => right.createdAtSortKey - left.createdAtSortKey);
}

function runOpenClaw(args, env = process.env) {
  return execFileSync("openclaw", args, {
    encoding: "utf8",
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
}

function devicesArgs(subcommand, env = process.env) {
  const args = ["devices", subcommand];
  const token = String(env.OPENCLAW_GATEWAY_TOKEN || "").trim();
  const url = String(env.OPENCLAW_GATEWAY_URL || "").trim();

  if (url) args.push("--url", url);
  if (token) args.push("--token", token);

  return args;
}

function fetchPendingRequests(env = process.env) {
  const output = runOpenClaw([...devicesArgs("list", env), "--json"], env);
  return normalizePendingRequests(JSON.parse(output));
}

function approveRequest(requestId, env = process.env) {
  const output = runOpenClaw([...devicesArgs("approve", env), requestId, "--json"], env);
  return JSON.parse(output);
}

function renderRequests(requests, selectedIndex) {
  const lines = [
    "",
    "Approve device",
    "Use Up/Down or j/k to choose, Enter to approve, q to quit.",
    "",
  ];

  for (let index = 0; index < requests.length; index += 1) {
    const request = requests[index];
    const prefix = index === selectedIndex ? ">" : " ";
    const scopes = request.scopes.length ? request.scopes.join(", ") : "none";
    lines.push(
      `${prefix} ${truncate(request.client, 28)} | ${truncate(request.platform, 20)} | ${truncate(request.remoteIp, 18)} | ${request.createdAt}`,
    );
    lines.push(`  role=${request.role} scopes=${truncate(scopes, 80)}`);
    lines.push(`  requestId=${request.requestId}`);
    lines.push("");
  }

  return lines.join("\n");
}

function clearScreen(output = process.stdout) {
  output.write("\u001b[2J\u001b[H");
}

function printStatus(message, output = process.stdout) {
  clearScreen(output);
  output.write(`${message}\n`);
}

async function choosePendingRequest(requests) {
  return new Promise((resolve) => {
    let selectedIndex = 0;
    const input = process.stdin;
    const output = process.stdout;

    readline.emitKeypressEvents(input);
    if (input.isTTY) input.setRawMode(true);

    const redraw = () => {
      clearScreen(output);
      output.write(renderRequests(requests, selectedIndex));
    };

    const cleanup = () => {
      input.removeListener("keypress", onKeypress);
      if (input.isTTY) input.setRawMode(false);
      input.pause();
    };

    const onKeypress = (_str, key) => {
      if (!key) return;

      if (key.name === "up" || key.name === "k") {
        selectedIndex = (selectedIndex - 1 + requests.length) % requests.length;
        redraw();
        return;
      }

      if (key.name === "down" || key.name === "j") {
        selectedIndex = (selectedIndex + 1) % requests.length;
        redraw();
        return;
      }

      if (key.name === "return") {
        cleanup();
        clearScreen(output);
        resolve(requests[selectedIndex]);
        return;
      }

      if (key.name === "q" || (key.ctrl && key.name === "c")) {
        cleanup();
        clearScreen(output);
        resolve(null);
      }
    };

    input.on("keypress", onKeypress);
    redraw();
  });
}

function printApprovalResult(result) {
  const requestId = requestIdOf(result);
  const deviceId = String(result?.deviceId || result?.approvedDeviceId || "unknown").trim();

  printStatus("Device approved.");
  console.log(`Approved device request ${requestId || "unknown"}.`);
  console.log(`deviceId=${deviceId}`);
}

async function main() {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error("approve-device requires an interactive terminal.");
  }

  const pendingRequests = fetchPendingRequests(process.env);

  if (pendingRequests.length === 0) {
    console.log("No pending device pairing requests.");
    return;
  }

  const selectedRequest = await choosePendingRequest(pendingRequests);
  if (!selectedRequest) {
    printStatus("No device approved.");
    console.log("No device approved.");
    return;
  }

  printStatus(
    `Approving ${selectedRequest.client} from ${selectedRequest.remoteIp} (${selectedRequest.platform})...`,
  );
  const result = approveRequest(selectedRequest.requestId, process.env);
  printApprovalResult(result);
}

if (require.main === module) {
  main().catch((error) => {
    const message = escapeAnsi(error?.stderr || error?.message || String(error));
    console.error(message);
    process.exit(1);
  });
}

module.exports = {
  devicesArgs,
  normalizePendingRequests,
  requestClientLabelOf,
  requestCreatedAtOf,
  requestIdOf,
  requestPlatformOf,
  requestRemoteIpOf,
  truncate,
};
