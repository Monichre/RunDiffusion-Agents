#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

[[ $# -eq 1 ]] || die "Usage: ./scripts/start-tenant.sh <slug>"

slug="$1"

load_root_env
require_base_commands
tenant_exists "${slug}" || die "Unknown tenant: ${slug}"

ensure_tenant_layout "${slug}"
render_traefik_dynamic_config >/dev/null
compose_shared up -d
OPENCLAW_IMAGE="$(default_image_ref "${slug}")"
export OPENCLAW_IMAGE

compose_tenant "${slug}" up -d
wait_for_tenant_healthy "${slug}"
smoke_test_tenant_local "${slug}"
note "Started tenant ${slug}"
