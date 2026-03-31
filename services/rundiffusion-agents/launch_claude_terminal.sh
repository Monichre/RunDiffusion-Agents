#!/usr/bin/env bash
set -euo pipefail

CLAUDE_WORKSPACE_DIR="${CLAUDE_WORKSPACE_DIR:-/data/workspaces/claude}"
CLAUDE_HOME="${CLAUDE_HOME:-/data/.claude}"
CLAUDE_ANTHROPIC_API_KEY="${CLAUDE_ANTHROPIC_API_KEY:-}"
AGENT_STATUS_DIR="${AGENT_STATUS_DIR:-/data/runtime/agent-status}"
RUNTIME_HOME="${HOME:-/root}"
STATUS_PATH="${AGENT_STATUS_DIR}/claude.json"

write_runtime_status() {
  local phase="$1"
  local mode="$2"
  local summary="$3"
  local detail="$4"
  local reason="${5:-}"
  local exit_code="${6:-}"

  mkdir -p "${AGENT_STATUS_DIR}"
  node - "${STATUS_PATH}" "${phase}" "${mode}" "${summary}" "${detail}" "${CLAUDE_WORKSPACE_DIR}" "${CLAUDE_HOME}" "${reason}" "${exit_code}" <<'NODE'
const fs = require("node:fs");

const [, , statusPath, phase, mode, summary, detail, workspaceDir, homeDir, reason, exitCode] = process.argv;
const payload = {
  updatedAt: new Date().toISOString(),
  phase,
  mode,
  summary,
  detail,
  workspaceDir,
  homeDir,
};

if (reason) payload.reason = reason;
if (exitCode) payload.exitCode = Number.parseInt(exitCode, 10);

fs.writeFileSync(statusPath, `${JSON.stringify(payload, null, 2)}\n`);
NODE
}

mkdir -p \
  "${CLAUDE_HOME}/.claude" \
  "${CLAUDE_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

ln -sfn "${CLAUDE_HOME}/.claude" "${RUNTIME_HOME}/.claude"
ln -sfn "${CLAUDE_HOME}/.claude.json" "${RUNTIME_HOME}/.claude.json"
write_runtime_status "starting" "cli" "Preparing Claude Code" "Configuring the Claude workspace and runtime."

cd "${CLAUDE_WORKSPACE_DIR}"

if ! command -v claude >/dev/null 2>&1; then
  write_runtime_status "fallback" "shell" "Claude Code unavailable" "Claude Code is not installed in this image, so the route opened a shell instead." "missing-binary"
  echo "[claude] Claude Code is not installed in this image; opening a shell instead."
  exec /bin/bash
fi

if [[ -n "${CLAUDE_ANTHROPIC_API_KEY}" ]]; then
  export ANTHROPIC_API_KEY="${CLAUDE_ANTHROPIC_API_KEY}"
fi

echo "[claude] Starting Claude Code in ${CLAUDE_WORKSPACE_DIR}"
echo "[claude] CLAUDE_HOME=${CLAUDE_HOME}"
if [[ -z "${CLAUDE_ANTHROPIC_API_KEY}" ]]; then
  echo "[claude] No Claude Code API key was preconfigured. Claude can log in interactively and persist that session in CLAUDE_HOME."
  write_runtime_status "running" "cli" "Claude waiting for login" "Claude Code launched. Sign in interactively in the terminal unless you add CLAUDE_ANTHROPIC_API_KEY."
else
  write_runtime_status "running" "cli" "Claude Code running" "Claude Code launched successfully in its dedicated tmux session."
fi
echo "[claude] Exit Claude to return to a shell."

set +e
claude
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  write_runtime_status "fallback" "shell" "Claude exited" "Claude Code exited and the tmux session returned to a shell." "cli-exited" "${status}"
  echo "[claude] Claude exited with status ${status}."
else
  write_runtime_status "fallback" "shell" "Claude closed" "Claude Code exited cleanly and the tmux session returned to a shell." "cli-exited" "${status}"
fi

echo "[claude] Opening a shell."
exec /bin/bash
