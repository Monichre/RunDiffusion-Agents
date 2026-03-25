#!/usr/bin/env bash
set -euo pipefail

GEMINI_WORKSPACE_DIR="${GEMINI_WORKSPACE_DIR:-/data/workspaces/gemini}"
GEMINI_HOME="${GEMINI_HOME:-/data/.gemini}"
GEMINI_CLI_API_KEY="${GEMINI_CLI_API_KEY:-}"
RUNTIME_HOME="${HOME:-/root}"

mkdir -p \
  "${GEMINI_HOME}" \
  "${GEMINI_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

ln -sfn "${GEMINI_HOME}" "${RUNTIME_HOME}/.gemini"

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
fi
echo "[gemini] Exit Gemini to return to a shell."

set +e
"${GEMINI_COMMAND}"
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[gemini] Gemini exited with status ${status}."
fi

echo "[gemini] Opening a shell."
exec /bin/bash
