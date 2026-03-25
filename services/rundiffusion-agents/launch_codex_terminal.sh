#!/usr/bin/env bash
set -euo pipefail

CODEX_WORKSPACE_DIR="${CODEX_WORKSPACE_DIR:-/data/workspaces/codex}"
CODEX_HOME="${CODEX_HOME:-/data/.codex}"
CODEX_OPENAI_API_KEY="${CODEX_OPENAI_API_KEY:-}"
MANAGED_CONFIG_PATH="${CODEX_HOME}/config.toml"
RUNTIME_HOME="${HOME:-/root}"

mkdir -p \
  "${CODEX_HOME}" \
  "${CODEX_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

ln -sfn "${CODEX_HOME}" "${RUNTIME_HOME}/.codex"

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
fi
echo "[codex] Exit Codex to return to a shell."

set +e
codex
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[codex] Codex exited with status ${status}."
fi

echo "[codex] Opening a shell."
exec /bin/bash
