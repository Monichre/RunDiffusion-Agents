#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/smoke-test.sh [--tenant slug | --all]
EOF
}

tenant_slug=""
test_all=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)
      tenant_slug="$2"
      shift 2
      ;;
    --all)
      test_all=1
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
require_command curl

smoke_test_shared_local
note "Shared Traefik health is healthy"

if ingress_uses_cloudflare; then
  smoke_test_tunnel_local
  note "cloudflared metrics are healthy"
fi

run_one() {
  local slug="$1"
  smoke_test_tenant_local "${slug}"
  note "Tenant ${slug} passed"
}

if [[ "${test_all}" -eq 1 ]]; then
  while IFS= read -r slug; do
    [[ -n "${slug}" ]] || continue
    run_one "${slug}"
  done <<EOF
$(tenant_slugs_enabled)
EOF
elif [[ -n "${tenant_slug}" ]]; then
  run_one "${tenant_slug}"
else
  usage >&2
  exit 1
fi
