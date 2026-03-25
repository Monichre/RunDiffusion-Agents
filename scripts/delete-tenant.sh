#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/delete-tenant.sh <slug> [--purge]

Removes the tenant from the registry and stops its stack.
Use --purge to also delete env, release metadata, backups, and tenant data.
EOF
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 1
}

slug="$1"
shift
purge=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)
      purge=1
      shift
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

load_root_env
require_base_commands
validate_slug "${slug}"
tenant_exists "${slug}" || die "Unknown tenant: ${slug}"
export SLUG="${slug}"

env_file="$(tenant_env_file "${slug}")"
data_root="$(tenant_data_root "${slug}")"
release_root="$(tenant_release_root "${slug}")"
backup_root="$(tenant_backup_root "${slug}")"

compose_tenant "${slug}" down --remove-orphans || true
yq eval -i 'del(.tenants[] | select(.slug == strenv(SLUG)))' "${TENANT_REGISTRY_FILE}"

if [[ "${purge}" -eq 1 ]]; then
  rm -rf "${env_file}" "${data_root}" "${release_root}" "${backup_root}"
fi

if ingress_uses_cloudflare; then
  render_cloudflared_config >/dev/null
fi
render_traefik_dynamic_config >/dev/null
note "Deleted tenant ${slug}"
