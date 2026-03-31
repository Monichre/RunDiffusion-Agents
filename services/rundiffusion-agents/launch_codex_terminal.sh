#!/usr/bin/env bash
set -euo pipefail

CODEX_WORKSPACE_DIR="${CODEX_WORKSPACE_DIR:-/data/workspaces/codex}"
CODEX_HOME="${CODEX_HOME:-/data/.codex}"
CODEX_OPENAI_API_KEY="${CODEX_OPENAI_API_KEY:-}"
AGENT_STATUS_DIR="${AGENT_STATUS_DIR:-/data/runtime/agent-status}"
MANAGED_CONFIG_PATH="${CODEX_HOME}/config.toml"
RUNTIME_HOME="${HOME:-/root}"
STATUS_PATH="${AGENT_STATUS_DIR}/codex.json"

write_runtime_status() {
  local phase="$1"
  local mode="$2"
  local summary="$3"
  local detail="$4"
  local reason="${5:-}"
  local exit_code="${6:-}"

  mkdir -p "${AGENT_STATUS_DIR}"
  node - "${STATUS_PATH}" "${phase}" "${mode}" "${summary}" "${detail}" "${CODEX_WORKSPACE_DIR}" "${CODEX_HOME}" "${reason}" "${exit_code}" <<'NODE'
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
  "${CODEX_HOME}" \
  "${CODEX_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

ln -sfn "${CODEX_HOME}" "${RUNTIME_HOME}/.codex"
write_runtime_status "starting" "cli" "Preparing Codex" "Configuring the Codex workspace and runtime."

if [[ ! -f "${MANAGED_CONFIG_PATH}" ]]; then
  cat > "${MANAGED_CONFIG_PATH}" <<'EOF'
# Managed by openclaw-gateway.
# Use the Codex CLI inside the terminal to inspect or update this file.
cli_auth_credentials_store = "file"
EOF
  chmod 600 "${MANAGED_CONFIG_PATH}"
fi

cd "${CODEX_WORKSPACE_DIR}"

if ! command -v codex >/dev/null 2>&1; then
  write_runtime_status "fallback" "shell" "Codex CLI unavailable" "Codex is not installed in this image, so the route opened a shell instead." "missing-binary"
  echo "[codex] Codex CLI is not installed in this image; opening a shell instead."
  exec /bin/bash
fi

export CODEX_HOME

if [[ -n "${CODEX_OPENAI_API_KEY}" ]]; then
  export OPENAI_API_KEY="${CODEX_OPENAI_API_KEY}"
fi

echo "[codex] Starting Codex in ${CODEX_WORKSPACE_DIR}"
echo "[codex] CODEX_HOME=${CODEX_HOME}"
if [[ -z "${CODEX_OPENAI_API_KEY}" ]]; then
  echo "[codex] No Codex API key was preconfigured. Use Codex login, or set CODEX_OPENAI_API_KEY if you explicitly want non-interactive auth."
  write_runtime_status "running" "cli" "Codex waiting for login" "Codex launched. Sign in interactively in the terminal unless you add CODEX_OPENAI_API_KEY."
else
  write_runtime_status "running" "cli" "Codex CLI running" "Codex launched successfully in its dedicated tmux session."
fi
echo "[codex] Exit Codex to return to a shell."

set +e
codex
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  write_runtime_status "fallback" "shell" "Codex exited" "Codex exited and the tmux session returned to a shell." "cli-exited" "${status}"
  echo "[codex] Codex exited with status ${status}."
else
  write_runtime_status "fallback" "shell" "Codex closed" "Codex exited cleanly and the tmux session returned to a shell." "cli-exited" "${status}"
fi

echo "[codex] Opening a shell."
exec /bin/bash
