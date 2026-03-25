#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/migrate-host-storage.sh [--from-data-root path] [--from-tenant-env-root path]

Copies legacy repo-local tenant storage into the current DATA_ROOT and TENANT_ENV_ROOT.

Defaults:
  from-data-root       <repo>/.data
  from-tenant-env-root <repo>/deploy/tenants/env
  to-data-root         DATA_ROOT from .env
  to-tenant-env-root   TENANT_ENV_ROOT from .env
EOF
}

source_data_root=""
source_tenant_env_root=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-data-root)
      source_data_root="$2"
      shift 2
      ;;
    --from-tenant-env-root)
      source_tenant_env_root="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

load_root_env

source_data_root="${source_data_root:-${REPO_ROOT}/.data}"
source_tenant_env_root="${source_tenant_env_root:-${REPO_ROOT}/deploy/tenants/env}"
destination_data_root="${DATA_ROOT}"
destination_tenant_env_root="${TENANT_ENV_ROOT}"

canonical_path() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

sync_tree() {
  local source_path="$1"
  local destination_path="$2"
  local label="$3"
  local resolved_source_path resolved_destination_path

  if [[ ! -d "${source_path}" ]]; then
    note "Skipping ${label}; source directory not found: ${source_path}"
    return 0
  fi

  ensure_directory "${destination_path}"
  resolved_source_path="$(canonical_path "${source_path}")"
  resolved_destination_path="$(canonical_path "${destination_path}")"

  if [[ "${resolved_source_path}" == "${resolved_destination_path}" ]]; then
    note "Skipping ${label}; source and destination match: ${source_path}"
    return 0
  fi

  note "Copying ${label}"
  note "  from: ${source_path}"
  note "  to:   ${destination_path}"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${source_path%/}/" "${destination_path%/}/"
  else
    cp -a "${source_path%/}/." "${destination_path%/}/"
  fi
}

sync_tree "${source_data_root}" "${destination_data_root}" "tenant data root"
sync_tree "${source_tenant_env_root}" "${destination_tenant_env_root}" "tenant env root"

note "Migration copy complete"
note "DATA_ROOT=${destination_data_root}"
note "TENANT_ENV_ROOT=${destination_tenant_env_root}"
note "Old copies were left in place for rollback safety"
