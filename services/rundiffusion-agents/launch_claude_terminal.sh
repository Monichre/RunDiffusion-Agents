#!/usr/bin/env bash
set -euo pipefail

CLAUDE_WORKSPACE_DIR="${CLAUDE_WORKSPACE_DIR:-/data/workspaces/claude}"
CLAUDE_HOME="${CLAUDE_HOME:-/data/.claude}"
CLAUDE_ANTHROPIC_API_KEY="${CLAUDE_ANTHROPIC_API_KEY:-}"
RUNTIME_HOME="${HOME:-/root}"

mkdir -p \
  "${CLAUDE_HOME}/.claude" \
  "${CLAUDE_WORKSPACE_DIR}" \
  "${RUNTIME_HOME}"

ln -sfn "${CLAUDE_HOME}/.claude" "${RUNTIME_HOME}/.claude"
ln -sfn "${CLAUDE_HOME}/.claude.json" "${RUNTIME_HOME}/.claude.json"

cd "${CLAUDE_WORKSPACE_DIR}"

if ! command -v claude >/dev/null 2>&1; then
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
fi
echo "[claude] Exit Claude to return to a shell."

set +e
claude
status=$?
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[claude] Claude exited with status ${status}."
fi

echo "[claude] Opening a shell."
exec /bin/bash
