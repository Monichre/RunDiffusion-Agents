#!/usr/bin/env bash
set -euo pipefail

GEMINI_WORKSPACE_DIR="${GEMINI_WORKSPACE_DIR:-/data/workspaces/gemini}"
GEMINI_HOME="${GEMINI_HOME:-/data/.gemini}"
GEMINI_CLI_API_KEY="${GEMINI_CLI_API_KEY:-}"
AGENT_STATUS_DIR="${AGENT_STATUS_DIR:-/data/runtime/agent-status}"
RUNTIME_HOME="${HOME:-/root}"
STATUS_PATH="${AGENT_STATUS_DIR}/gemini.json"

write_runtime_status() {
  local phase="$1"
  local mode="$2"
  local summary="$3"
  local detail="$4"
  local reason="${5:-}"
  local exit_code="${6:-}"

  mkdir -p "${AGENT_STATUS_DIR}"
  node - "${STATUS_PATH}" "${phase}" "${mode}" "${summary}" "${detail}" "${GEMINI_WORKSPACE_DIR}" "${GEMINI_HOME}" "${reason}" "${exit_code}" <<'NODE'
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
  "${GEMINI_HOME}" \
  "${GEMINI_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

ln -sfn "${GEMINI_HOME}" "${RUNTIME_HOME}/.gemini"
write_runtime_status "starting" "cli" "Preparing Gemini" "Configuring the Gemini workspace and runtime."

cd "${GEMINI_WORKSPACE_DIR}"

resolve_gemini_command() {
  if command -v gemini >/dev/null 2>&1; then
    command -v gemini
    return 0
  fi

  find /usr/local/lib/node_modules/@google -maxdepth 3 -path '/usr/local/lib/node_modules/@google/.gemini-cli-*/dist/index.js' | head -n 1
}

GEMINI_COMMAND="$(resolve_gemini_command)"

if [[ -z "${GEMINI_COMMAND}" ]]; then
  write_runtime_status "fallback" "shell" "Gemini CLI unavailable" "Gemini is not installed in this image, so the route opened a shell instead." "missing-binary"
  echo "[gemini] Gemini CLI is not installed in this image; opening a shell instead."
  exec /bin/bash
fi

if [[ -n "${GEMINI_CLI_API_KEY}" ]]; then
  export GEMINI_API_KEY="${GEMINI_CLI_API_KEY}"
else
  unset GEMINI_API_KEY || true
fi

echo "[gemini] Starting Gemini CLI in ${GEMINI_WORKSPACE_DIR}"
echo "[gemini] GEMINI_HOME=${GEMINI_HOME}"
if [[ -z "${GEMINI_CLI_API_KEY}" ]]; then
  echo "[gemini] No Gemini CLI API key was preconfigured. Gemini can log in interactively with Google and persist that session in GEMINI_HOME."
  write_runtime_status "running" "cli" "Gemini waiting for login" "Gemini launched. Sign in interactively in the terminal unless you add GEMINI_CLI_API_KEY."
else
  write_runtime_status "running" "cli" "Gemini CLI running" "Gemini launched successfully in its dedicated tmux session."
fi
echo "[gemini] Exit Gemini to return to a shell."

set +e
"${GEMINI_COMMAND}"
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  write_runtime_status "fallback" "shell" "Gemini exited" "Gemini exited and the tmux session returned to a shell." "cli-exited" "${status}"
  echo "[gemini] Gemini exited with status ${status}."
else
  write_runtime_status "fallback" "shell" "Gemini closed" "Gemini exited cleanly and the tmux session returned to a shell." "cli-exited" "${status}"
fi

echo "[gemini] Opening a shell."
exec /bin/bash
