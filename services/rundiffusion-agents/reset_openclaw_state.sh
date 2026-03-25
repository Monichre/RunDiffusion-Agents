#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${OPENCLAW_ENV_FILE:-${SCRIPT_DIR}/.env}"
LOAD_ENV_FILE="${OPENCLAW_RESET_LOAD_ENV_FILE:-1}"

if [[ "${LOAD_ENV_FILE}" == "1" && -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspaces/openclaw}"
CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-${STATE_DIR}/openclaw.json}"
BACKUP_ROOT="${OPENCLAW_RESET_BACKUP_ROOT:-$(dirname "${STATE_DIR}")/openclaw-reset-backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"
MANIFEST_PATH="${BACKUP_DIR}/manifest.txt"
backed_up_anything=0

require_safe_target() {
  local target="$1"

  case "${target}" in
    ""|"/"|"."|"..")
      echo "[reset-openclaw-state] Refusing unsafe target: ${target}"
      exit 1
      ;;
  esac
}

copy_tree() {
  local src="$1"
  local label="$2"

  if [[ ! -e "${src}" ]]; then
    return 0
  fi

  mkdir -p "${BACKUP_DIR}"
  cp -a "${src}" "${BACKUP_DIR}/${label}"
  backed_up_anything=1
  echo "[reset-openclaw-state] Backed up ${src} -> ${BACKUP_DIR}/${label}"
}

remove_tree() {
  local target="$1"

  if [[ ! -e "${target}" ]]; then
    return 0
  fi

  require_safe_target "${target}"
  rm -rf "${target}"
  echo "[reset-openclaw-state] Removed ${target}"
}

mkdir -p "${BACKUP_DIR}"
{
  printf 'createdAt=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'stateDir=%s\n' "${STATE_DIR}"
  printf 'workspaceDir=%s\n' "${WORKSPACE_DIR}"
  printf 'configPath=%s\n' "${CONFIG_PATH}"
} > "${MANIFEST_PATH}"

copy_tree "${STATE_DIR}" "openclaw-state"
if [[ "${CONFIG_PATH}" != "${STATE_DIR}/openclaw.json" ]]; then
  copy_tree "${CONFIG_PATH}" "openclaw-config.json"
fi
copy_tree "${WORKSPACE_DIR}" "openclaw-workspace"

if [[ "${backed_up_anything}" -eq 0 ]]; then
  printf 'note=no-existing-openclaw-state-found\n' >> "${MANIFEST_PATH}"
  echo "[reset-openclaw-state] No existing OpenClaw state was found; wrote manifest only."
fi

remove_tree "${STATE_DIR}"
remove_tree "${WORKSPACE_DIR}"

echo "[reset-openclaw-state] Reset complete."
echo "[reset-openclaw-state] Backup location: ${BACKUP_DIR}"
