const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const {
  buildToolRuntimeCatalog,
  listToolRuntimeStatuses,
  relaunchToolRuntime,
} = require("../dashboard_server");

function withTempEnv(callback) {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "dashboard-server-test-"));
  try {
    return callback(tempDir);
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

test("buildToolRuntimeCatalog uses env overrides and status dir", () => {
  const catalog = buildToolRuntimeCatalog({
    AGENT_STATUS_DIR: "/tmp/status",
    HERMES_SESSION_NAME: "custom-hermes",
    HERMES_WORKSPACE_DIR: "/workspace/hermes",
  });

  assert.equal(catalog.hermes.sessionName, "custom-hermes");
  assert.equal(catalog.hermes.workspaceDir, "/workspace/hermes");
  assert.equal(catalog.hermes.statusPath, "/tmp/status/hermes.json");
});

test("listToolRuntimeStatuses reports disabled and unread status files", () => {
  withTempEnv((tempDir) => {
    fs.mkdirSync(path.join(tempDir, "status"), { recursive: true });
    fs.writeFileSync(path.join(tempDir, "status", "codex.json"), "{not-json}\n");

    const statuses = listToolRuntimeStatuses({
      AGENT_STATUS_DIR: path.join(tempDir, "status"),
      HERMES_ENABLED: "0",
    });

    assert.equal(statuses.hermes.phase, "disabled");
    assert.equal(statuses.hermes.canRelaunch, false);
    assert.equal(statuses.codex.phase, "attention");
    assert.match(statuses.codex.detail, /Unexpected token|Expected property name/);
    assert.equal(statuses.gemini.phase, "unknown");
  });
});

test("relaunchToolRuntime respawns existing tmux sessions", () => {
  const calls = [];
  const fakeExec = (command, args) => {
    calls.push([command, ...args]);
    return "";
  };

  relaunchToolRuntime(
    "gemini",
    {
      AGENT_STATUS_DIR: "/tmp/status",
      GEMINI_SESSION_NAME: "gemini-main",
      GEMINI_WORKSPACE_DIR: "/workspace/gemini",
    },
    fakeExec,
  );

  assert.deepEqual(calls[0], ["tmux", "has-session", "-t", "gemini-main"]);
  assert.deepEqual(calls[1], ["tmux", "respawn-pane", "-k", "-t", "gemini-main:0.0", "/app/launch_gemini_terminal.sh"]);
});

test("relaunchToolRuntime creates tmux session when none exists", () => {
  const calls = [];
  const fakeExec = (command, args) => {
    calls.push([command, ...args]);
    if (args[0] === "has-session") {
      throw new Error("missing session");
    }
    return "";
  };

  relaunchToolRuntime(
    "claude",
    {
      AGENT_STATUS_DIR: "/tmp/status",
      CLAUDE_SESSION_NAME: "claude-main",
      CLAUDE_WORKSPACE_DIR: "/workspace/claude",
    },
    fakeExec,
  );

  assert.deepEqual(calls[0], ["tmux", "has-session", "-t", "claude-main"]);
  assert.deepEqual(calls[1], ["tmux", "new-session", "-d", "-s", "claude-main", "-c", "/workspace/claude", "/app/launch_claude_terminal.sh"]);
});
