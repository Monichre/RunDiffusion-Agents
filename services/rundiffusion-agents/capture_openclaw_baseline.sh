#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${OPENCLAW_ENV_FILE:-${SCRIPT_DIR}/.env}"
LOAD_ENV_FILE="${OPENCLAW_CAPTURE_LOAD_ENV_FILE:-1}"

if [[ "${LOAD_ENV_FILE}" == "1" && -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspaces/openclaw}"
CAPTURE_ROOT="${OPENCLAW_CAPTURE_ROOT:-$(dirname "${STATE_DIR}")/openclaw-baselines}"
CAPTURE_LABEL="${OPENCLAW_CAPTURE_LABEL:-manual-onboarding}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
CAPTURE_DIR="${CAPTURE_ROOT}/${STAMP}-${CAPTURE_LABEL}"
MANIFEST_PATH="${CAPTURE_DIR}/manifest.txt"
captured_anything=0

copy_tree() {
  local src="$1"
  local label="$2"

  if [[ ! -e "${src}" ]]; then
    return 0
  fi

  mkdir -p "${CAPTURE_DIR}"
  cp -a "${src}" "${CAPTURE_DIR}/${label}"
  captured_anything=1
  echo "[capture-openclaw-baseline] Captured ${src} -> ${CAPTURE_DIR}/${label}"
}

mkdir -p "${CAPTURE_DIR}"
{
  printf 'createdAt=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'captureLabel=%s\n' "${CAPTURE_LABEL}"
  printf 'stateDir=%s\n' "${STATE_DIR}"
  printf 'workspaceDir=%s\n' "${WORKSPACE_DIR}"
} > "${MANIFEST_PATH}"

copy_tree "${STATE_DIR}" "openclaw-state"
copy_tree "${WORKSPACE_DIR}" "openclaw-workspace"

if [[ "${captured_anything}" -eq 0 ]]; then
  printf 'note=no-openclaw-state-found\n' >> "${MANIFEST_PATH}"
  echo "[capture-openclaw-baseline] No OpenClaw state was found; wrote manifest only."
fi

echo "[capture-openclaw-baseline] Capture complete."
echo "[capture-openclaw-baseline] Capture location: ${CAPTURE_DIR}"
